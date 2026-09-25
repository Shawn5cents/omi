import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'package:omi/models/stt_result.dart';
import 'package:omi/services/custom_stt_log_service.dart';
import 'package:omi/services/sockets/on_device_transcript_quality_gate.dart';
import 'package:omi/services/sockets/pure_polling.dart';

class OmiPlusPcmWave {
  const OmiPlusPcmWave({
    required this.samples,
    required this.sampleRate,
  });

  final Float32List samples;
  final int sampleRate;

  double get durationSeconds => samples.length / sampleRate;
}

@visibleForTesting
OmiPlusPcmWave decodeOmiPlusPcm16Wav(Uint8List bytes) {
  if (bytes.length < 44) {
    throw const FormatException('WAV is too short');
  }

  String fourCc(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

  if (fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
    throw const FormatException('Expected RIFF/WAVE input');
  }

  final view = ByteData.sublistView(bytes);
  int? sampleRate;
  int? channels;
  int? bitsPerSample;
  int? audioFormat;
  int? dataOffset;
  int? dataLength;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = fourCc(offset);
    final chunkLength = view.getUint32(offset + 4, Endian.little);
    final chunkData = offset + 8;
    if (chunkData + chunkLength > bytes.length) {
      throw const FormatException('Truncated WAV chunk');
    }

    if (chunkId == 'fmt ') {
      if (chunkLength < 16) {
        throw const FormatException('Invalid WAV fmt chunk');
      }
      audioFormat = view.getUint16(chunkData, Endian.little);
      channels = view.getUint16(chunkData + 2, Endian.little);
      sampleRate = view.getUint32(chunkData + 4, Endian.little);
      bitsPerSample = view.getUint16(chunkData + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkData;
      dataLength = chunkLength;
    }

    offset = chunkData + chunkLength + (chunkLength.isOdd ? 1 : 0);
  }

  if (audioFormat != 1 || bitsPerSample != 16) {
    throw FormatException(
      'Moonshine requires PCM16 WAV (format=$audioFormat bits=$bitsPerSample)',
    );
  }
  if (channels == null || channels <= 0 || sampleRate == null || sampleRate <= 0) {
    throw const FormatException('Invalid WAV format metadata');
  }
  if (dataOffset == null || dataLength == null || dataLength <= 0) {
    throw const FormatException('WAV contains no audio data');
  }

  final frameBytes = channels * 2;
  final frameCount = dataLength ~/ frameBytes;
  final samples = Float32List(frameCount);
  var byteOffset = dataOffset;

  for (var frame = 0; frame < frameCount; frame++) {
    var mixed = 0.0;
    for (var channel = 0; channel < channels; channel++) {
      mixed += view.getInt16(byteOffset, Endian.little) / 32768.0;
      byteOffset += 2;
    }
    samples[frame] = mixed / channels;
  }

  return OmiPlusPcmWave(samples: samples, sampleRate: sampleRate);
}

class OnDeviceMoonshineProvider implements ISttProvider {
  OnDeviceMoonshineProvider({required this.modelDir});

  final String modelDir;
  final OnDeviceTranscriptQualityGate _qualityGate = OnDeviceTranscriptQualityGate();

  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  SendPort? _workerPort;
  Completer<void>? _initCompleter;
  int _nextRequestId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<void> _ensureInitialized() async {
    if (_workerPort != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final requiredFiles = [
      File('$modelDir/encoder_model.ort'),
      File('$modelDir/decoder_model_merged.ort'),
      File('$modelDir/tokens.txt'),
    ];
    for (final file in requiredFiles) {
      if (!await file.exists()) {
        throw StateError('Moonshine model file missing: ${file.path}');
      }
    }

    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;
    _receivePort = ReceivePort();
    _receiveSubscription = _receivePort!.listen(_handleWorkerMessage);

    try {
      _isolate = await Isolate.spawn<List<Object?>>(
        _moonshineWorkerEntry,
        <Object?>[modelDir, _receivePort!.sendPort],
        debugName: 'omi-plus-moonshine',
      );
      await initCompleter.future.timeout(const Duration(seconds: 20));
      CustomSttLogService.instance.info(
        'OnDeviceMoonshine',
        'Initialized Moonshine Tiny v2 in $modelDir',
      );
    } catch (e) {
      _initCompleter = null;
      await _receiveSubscription?.cancel();
      _receiveSubscription = null;
      _receivePort?.close();
      _receivePort = null;
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      rethrow;
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type']?.toString();

    if (type == 'ready') {
      final port = message['port'];
      if (port is SendPort) {
        _workerPort = port;
        final completer = _initCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
      return;
    }

    if (type == 'init_error') {
      final error = message['error']?.toString() ?? 'Moonshine init failed';
      final completer = _initCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(StateError(error));
      }
      return;
    }

    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;

    if (type == 'result') {
      completer.complete(Map<String, dynamic>.from(message));
    } else {
      completer.completeError(
        StateError(message['error']?.toString() ?? 'Moonshine decode failed'),
      );
    }
  }

  @override
  Future<SttTranscriptionResult?> transcribe(
    Uint8List audioData, {
    double audioOffsetSeconds = 0,
    String? language,
  }) async {
    try {
      final totalWatch = Stopwatch()..start();
      final wave = decodeOmiPlusPcm16Wav(audioData);
      await _ensureInitialized();

      final port = _workerPort;
      if (port == null) {
        throw StateError('Moonshine worker is not ready');
      }

      final id = _nextRequestId++;
      final completer = Completer<Map<String, dynamic>>();
      _pending[id] = completer;
      port.send(<String, Object?>{
        'type': 'decode',
        'id': id,
        'samples': wave.samples,
        'sampleRate': wave.sampleRate,
      });

      final response = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _pending.remove(id);
          throw TimeoutException('Moonshine transcription timed out');
        },
      );

      var cleanText = (response['text']?.toString() ?? '').trim();
      if (cleanText.isEmpty) return null;
      cleanText = cleanText.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      cleanText = cleanText.replaceAll(RegExp(r'\(.*?\)'), '').trim();

      final filteredText = _qualityGate.filter(
        cleanText,
        audioData: audioData,
      );
      if (filteredText == null) {
        CustomSttLogService.instance.warning(
          'OnDeviceMoonshine',
          'Dropped low-quality local transcript: $cleanText',
        );
        return null;
      }

      totalWatch.stop();
      final decodeMs =
          response['elapsedMs'] is num ? (response['elapsedMs'] as num).toInt() : totalWatch.elapsedMilliseconds;
      final realtimeFactor = decodeMs / 1000.0 / wave.durationSeconds.clamp(0.001, double.infinity);

      CustomSttLogService.instance.info(
        'OnDeviceMoonshine',
        'Transcribed ${wave.durationSeconds.toStringAsFixed(1)}s in '
            '${decodeMs}ms (${realtimeFactor.toStringAsFixed(2)}x real-time; '
            'total ${totalWatch.elapsedMilliseconds}ms). Text: $filteredText',
      );

      return SttTranscriptionResult(
        segments: [
          SttSegment(
            text: filteredText,
            start: audioOffsetSeconds,
            end: audioOffsetSeconds + wave.durationSeconds,
            speakerId: 0,
          ),
        ],
        rawText: filteredText,
      );
    } catch (e) {
      CustomSttLogService.instance.error(
        'OnDeviceMoonshine',
        'Transcription error: $e',
      );
      return null;
    }
  }

  @override
  void dispose() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Moonshine provider disposed'));
      }
    }
    _pending.clear();
    _workerPort?.send(const <String, Object?>{'type': 'dispose'});
    _workerPort = null;
    _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _initCompleter = null;
  }
}

void _moonshineWorkerEntry(List<Object?> args) {
  final modelDir = args[0]! as String;
  final mainPort = args[1]! as SendPort;
  sherpa_onnx.OfflineRecognizer? recognizer;
  final receivePort = ReceivePort();

  try {
    sherpa_onnx.initBindings();
    final config = sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        moonshine: sherpa_onnx.OfflineMoonshineModelConfig(
          encoder: '$modelDir/encoder_model.ort',
          mergedDecoder: '$modelDir/decoder_model_merged.ort',
        ),
        tokens: '$modelDir/tokens.txt',
        numThreads: 2,
        debug: false,
      ),
    );
    recognizer = sherpa_onnx.OfflineRecognizer(config);
    mainPort.send(<String, Object?>{
      'type': 'ready',
      'port': receivePort.sendPort,
    });
  } catch (e) {
    mainPort.send(<String, Object?>{
      'type': 'init_error',
      'error': e.toString(),
    });
    receivePort.close();
    return;
  }

  receivePort.listen((dynamic message) {
    if (message is! Map) return;
    final type = message['type']?.toString();
    if (type == 'dispose') {
      recognizer?.free();
      receivePort.close();
      return;
    }
    if (type != 'decode') return;

    final id = message['id'];
    final samples = message['samples'];
    final sampleRate = message['sampleRate'];
    if (id is! int || samples is! Float32List || sampleRate is! int) {
      return;
    }

    sherpa_onnx.OfflineStream? stream;
    try {
      final watch = Stopwatch()..start();
      stream = recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      watch.stop();
      mainPort.send(<String, Object?>{
        'type': 'result',
        'id': id,
        'text': result.text,
        'elapsedMs': watch.elapsedMilliseconds,
      });
    } catch (e) {
      mainPort.send(<String, Object?>{
        'type': 'decode_error',
        'id': id,
        'error': e.toString(),
      });
    } finally {
      stream?.free();
    }
  });
}
