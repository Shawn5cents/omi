import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:omi/backend/http/api/messages.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/services/freemium_transcription_service.dart';
import 'package:omi/services/omi_plus/omi_plus_mode.dart';
import 'package:omi/services/sockets/on_device_whisper_provider.dart';

typedef OmiPlusCloudTranscriber = Future<String> Function(List<File> files);
typedef OmiPlusLocalTranscriber = Future<String?> Function(File file);

OnDeviceWhisperProvider? _cachedCommandWhisperProvider;
String? _cachedCommandModelPath;
String? _cachedCommandLanguage;

@visibleForTesting
String resolveOmiPlusCommandLanguage({
  String? preferredLanguage,
  String? platformLocale,
}) {
  final preferred = (preferredLanguage ?? '').trim().toLowerCase();
  if (preferred.isNotEmpty && preferred != 'multi') {
    return preferred.split(RegExp(r'[-_]')).first;
  }

  final locale = (platformLocale ?? Platform.localeName).trim().toLowerCase();
  if (locale.isNotEmpty && locale != 'c') {
    final language = locale.split(RegExp(r'[-_]')).first;
    if (language.length >= 2 && language.length <= 3) return language;
  }

  return 'en';
}

OnDeviceWhisperProvider _getCommandWhisperProvider({
  required String modelPath,
  required String language,
}) {
  if (_cachedCommandWhisperProvider == null ||
      _cachedCommandModelPath != modelPath ||
      _cachedCommandLanguage != language) {
    _cachedCommandWhisperProvider?.dispose();
    _cachedCommandWhisperProvider = OnDeviceWhisperProvider(
      modelPath: modelPath,
      language: language,
    );
    _cachedCommandModelPath = modelPath;
    _cachedCommandLanguage = language;
  }
  return _cachedCommandWhisperProvider!;
}

@visibleForTesting
void resetOmiPlusCommandWhisperCache() {
  _cachedCommandWhisperProvider?.dispose();
  _cachedCommandWhisperProvider = null;
  _cachedCommandModelPath = null;
  _cachedCommandLanguage = null;
}

Future<String?> _defaultLocalTranscriber(File file) async {
  final freemium = FreemiumTranscriptionService();
  final readiness = await freemium.checkReadiness();
  final modelPath = freemium.cachedModelPath;
  if (readiness != FreemiumReadiness.ready || modelPath == null) {
    throw StateError(
      'Local Omi+ transcription is enabled but no on-device Whisper model is ready. '
      'Download a model in Settings > Transcription.',
    );
  }

  final language = resolveOmiPlusCommandLanguage(
    preferredLanguage: SharedPreferencesUtil().userPrimaryLanguage,
  );
  final provider = _getCommandWhisperProvider(
    modelPath: modelPath,
    language: language,
  );
  final result = await provider.transcribe(await file.readAsBytes());
  return result?.rawText;
}

Future<String> transcribeOmiPlusCommand(
  File file, {
  required bool localEnabled,
  OmiPlusCloudTranscriber cloudTranscriber = transcribeVoiceMessage,
  OmiPlusLocalTranscriber localTranscriber = _defaultLocalTranscriber,
}) async {
  final useLocal = OmiPlusMode.standalone || localEnabled;
  if (!useLocal) {
    final transcript = (await cloudTranscriber([file])).trim();
    if (transcript.isEmpty) {
      throw StateError('Omi transcription returned no speech.');
    }
    return transcript;
  }

  final transcript = (await localTranscriber(file))?.trim() ?? '';
  if (transcript.isEmpty) {
    throw StateError('Local Omi+ transcription returned no speech.');
  }
  return transcript;
}
