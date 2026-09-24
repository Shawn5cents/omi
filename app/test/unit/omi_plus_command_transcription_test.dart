import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:omi/services/omi_plus/omi_plus_command_transcription.dart';

void main() {
  late File audioFile;

  setUp(() async {
    audioFile = File('${Directory.systemTemp.path}/omi_plus_stt_test.wav');
    await audioFile.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await audioFile.exists()) await audioFile.delete();
  });

  test('uses cloud transcription when local STT is disabled', () async {
    var localCalled = false;
    final result = await transcribeOmiPlusCommand(
      audioFile,
      localEnabled: false,
      cloudTranscriber: (_) async => ' cloud answer ',
      localTranscriber: (_) async {
        localCalled = true;
        return 'local answer';
      },
    );

    expect(result, 'cloud answer');
    expect(localCalled, isFalse);
  });

  test('uses only local transcription when local STT is enabled', () async {
    var cloudCalled = false;
    final result = await transcribeOmiPlusCommand(
      audioFile,
      localEnabled: true,
      cloudTranscriber: (_) async {
        cloudCalled = true;
        return 'cloud answer';
      },
      localTranscriber: (_) async => ' local answer ',
    );

    expect(result, 'local answer');
    expect(cloudCalled, isFalse);
  });

  test('local failure does not silently fall back to cloud', () async {
    var cloudCalled = false;

    await expectLater(
      transcribeOmiPlusCommand(
        audioFile,
        localEnabled: true,
        cloudTranscriber: (_) async {
          cloudCalled = true;
          return 'cloud answer';
        },
        localTranscriber: (_) async => '',
      ),
      throwsStateError,
    );

    expect(cloudCalled, isFalse);
  });
}
