import 'package:flutter_test/flutter_test.dart';
import 'package:omi/models/omi_plus_settings.dart';

void main() {
  test('stock settings remain additive and disabled by default', () {
    const settings = OmiPlusSettings();
    expect(settings.enabled, isFalse);
    expect(settings.assistantTarget, OmiPlusAssistantTarget.omi);
    expect(settings.localSttEnabled, isFalse);
    expect(settings.localTtsEnabled, isFalse);
  });

  test('unknown stored provider fails closed to Omi in stock mode', () {
    expect(OmiPlusAssistantTarget.fromStorage('unknown'), OmiPlusAssistantTarget.omi);
    expect(OmiPlusAssistantTarget.fromStorage(null), OmiPlusAssistantTarget.omi);
  });

  test('known providers round trip by storage name', () {
    for (final target in OmiPlusAssistantTarget.values) {
      expect(OmiPlusAssistantTarget.fromStorage(target.name), target);
    }
  });
}
