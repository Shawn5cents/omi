import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';

const _hayaiEngine = 'dev.ahmedmohamed.hayaitts';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HayaiTTS Piper engine is installed and synthesizes offline', (tester) async {
    final tts = FlutterTts();
    final engines = await tts.getEngines;
    final names = engines is List ? engines.map((e) => e.toString()).toSet() : <String>{};

    expect(names, contains(_hayaiEngine));

    await tts.setEngine(_hayaiEngine);
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);

    await tts.speak('Omi plus local Piper voice is ready.');
    await tts.stop();
  });
}
