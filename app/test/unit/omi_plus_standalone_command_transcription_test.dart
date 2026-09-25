import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omi/services/omi_plus/omi_plus_command_transcription.dart';
import 'package:omi/services/omi_plus/omi_plus_mode.dart';

void main() {
  late File audioFile;

  setUp(() async {
    audioFile = File('${Directory.systemTemp.path}/omi_plus_standalone_command.wav');
    await audioFile.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await audioFile.exists()) await audioFile.delete();
  });

  test('standalone mode forces local transcription even when the toggle is false', () async {
    expect(OmiPlusMode.standalone, isTrue);

    var cloudCalled = false;
    var localCalled = false;
    final result = await transcribeOmiPlusCommand(
      audioFile,
      localEnabled: false,
      cloudTranscriber: (_) async {
        cloudCalled = true;
        return 'cloud';
      },
      localTranscriber: (_) async {
        localCalled = true;
        return 'local only';
      },
    );

    expect(result, 'local only');
    expect(localCalled, isTrue);
    expect(cloudCalled, isFalse);
  });

  test('language resolution prefers app language then device locale', () {
    expect(
      resolveOmiPlusCommandLanguage(
        preferredLanguage: 'en-US',
        platformLocale: 'es_ES',
      ),
      'en',
    );
    expect(
      resolveOmiPlusCommandLanguage(
        preferredLanguage: '',
        platformLocale: 'en_US',
      ),
      'en',
    );
    expect(
      resolveOmiPlusCommandLanguage(
        preferredLanguage: 'multi',
        platformLocale: 'es_ES',
      ),
      'es',
    );
  });
}
