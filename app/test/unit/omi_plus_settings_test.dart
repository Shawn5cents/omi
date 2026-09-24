import 'package:flutter_test/flutter_test.dart';
import 'package:omi/models/omi_plus_settings.dart';

void main() {
  test('Omi+ is disabled and stock Omi is the default', () {
    const settings = OmiPlusSettings();
    expect(settings.enabled, isFalse);
    expect(settings.assistantTarget, OmiPlusAssistantTarget.omi);
    expect(settings.localSttEnabled, isFalse);
    expect(settings.localTtsEnabled, isFalse);
  });

  test('unknown stored provider fails closed to Omi', () {
    expect(OmiPlusAssistantTarget.fromStorage('unknown'), OmiPlusAssistantTarget.omi);
    expect(OmiPlusAssistantTarget.fromStorage(null), OmiPlusAssistantTarget.omi);
  });

  test('known providers round trip by storage name', () {
    for (final target in OmiPlusAssistantTarget.values) {
      expect(OmiPlusAssistantTarget.fromStorage(target.name), target);
    }
  });
}
