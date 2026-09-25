import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:omi/backend/http/api/messages.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/services/custom_stt_log_service.dart';
import 'package:omi/services/freemium_transcription_service.dart';
import 'package:omi/services/omi_plus/omi_plus_mode.dart';
import 'package:omi/services/sockets/on_device_moonshine_provider.dart';
import 'package:omi/services/sockets/on_device_whisper_provider.dart';

typedef OmiPlusCloudTranscriber = Future<String> Function(List<File> files);
typedef OmiPlusLocalTranscriber = Future<String?> Function(File file);

const String _omiPlusSttEngine = String.fromEnvironment(
  'OMI_PLUS_STT_ENGINE',
  defaultValue: 'auto',
);
const String _moonshineModelDirectoryName = 'sherpa-onnx-moonshine-tiny-en-quantized-2026-02-27';

OnDeviceWhisperProvider? _cachedCommandWhisperProvider;
String? _cachedCommandModelPath;
String? _cachedCommandLanguage;
OnDeviceMoonshineProvider? _cachedCommandMoonshineProvider;
String? _cachedCommandMoonshineModelDir;

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

Future<String?> _findMoonshineModelDir() async {
  final supportDir = await getApplicationSupportDirectory();
  final modelDir = Directory(
    '${supportDir.path}/models/$_moonshineModelDirectoryName',
  );
  final required = [
    File('${modelDir.path}/encoder_model.ort'),
    File('${modelDir.path}/decoder_model_merged.ort'),
    File('${modelDir.path}/tokens.txt'),
  ];
  for (final file in required) {
    if (!await file.exists()) return null;
  }
  return modelDir.path;
}

OnDeviceMoonshineProvider _getCommandMoonshineProvider(String modelDir) {
  if (_cachedCommandMoonshineProvider == null || _cachedCommandMoonshineModelDir != modelDir) {
    _cachedCommandMoonshineProvider?.dispose();
    _cachedCommandMoonshineProvider = OnDeviceMoonshineProvider(
      modelDir: modelDir,
    );
    _cachedCommandMoonshineModelDir = modelDir;
  }
  return _cachedCommandMoonshineProvider!;
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
  _cachedCommandMoonshineProvider?.dispose();
  _cachedCommandMoonshineProvider = null;
  _cachedCommandMoonshineModelDir = null;
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
  final audioBytes = await file.readAsBytes();
  final requestedEngine = _omiPlusSttEngine.trim().toLowerCase();
  final allowMoonshine = language == 'en' && requestedEngine != 'whisper';

  if (allowMoonshine) {
    final moonshineDir = await _findMoonshineModelDir();
    if (moonshineDir != null) {
      final moonshine = _getCommandMoonshineProvider(moonshineDir);
      final result = await moonshine.transcribe(audioBytes);
      final text = (result?.rawText ?? '').trim();
      if (text.isNotEmpty) return text;
      CustomSttLogService.instance.warning(
        'OmiPlusCommandStt',
        'Moonshine returned no usable transcript; falling back to Whisper.',
      );
    } else if (requestedEngine == 'moonshine') {
      throw StateError(
        'OMI_PLUS_STT_ENGINE=moonshine but the Moonshine model is not installed.',
      );
    }
  }

  final provider = _getCommandWhisperProvider(
    modelPath: modelPath,
    language: language,
  );
  final result = await provider.transcribe(audioBytes);
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
