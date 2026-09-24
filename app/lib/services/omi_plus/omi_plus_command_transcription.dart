import 'dart:io';

import 'package:omi/backend/http/api/messages.dart';
import 'package:omi/services/freemium_transcription_service.dart';
import 'package:omi/services/sockets/on_device_whisper_provider.dart';

typedef OmiPlusCloudTranscriber = Future<String> Function(List<File> files);
typedef OmiPlusLocalTranscriber = Future<String?> Function(File file);

Future<String?> _defaultLocalTranscriber(File file) async {
  final freemium = FreemiumTranscriptionService();
  final readiness = await freemium.checkReadiness();
  if (readiness != FreemiumReadiness.ready || freemium.cachedModelPath == null) {
    throw StateError(
      'Local Omi+ transcription is enabled but no on-device Whisper model is ready. '
      'Download a model in Settings > Transcription.',
    );
  }

  final provider = OnDeviceWhisperProvider(
    modelPath: freemium.cachedModelPath!,
    language: 'multi',
  );
  try {
    final result = await provider.transcribe(await file.readAsBytes());
    return result?.rawText;
  } finally {
    provider.dispose();
  }
}

Future<String> transcribeOmiPlusCommand(
  File file, {
  required bool localEnabled,
  OmiPlusCloudTranscriber cloudTranscriber = transcribeVoiceMessage,
  OmiPlusLocalTranscriber localTranscriber = _defaultLocalTranscriber,
}) async {
  if (!localEnabled) {
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
