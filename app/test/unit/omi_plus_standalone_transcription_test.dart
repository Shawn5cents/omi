import 'package:flutter_test/flutter_test.dart';
import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/models/custom_stt_config.dart';
import 'package:omi/models/stt_provider.dart';
import 'package:omi/services/omi_plus/omi_plus_mode.dart';
import 'package:omi/services/sockets/transcription_service.dart';

void main() {
  test('standalone Omi+ uses only the local STT socket', () {
    expect(OmiPlusMode.standalone, isTrue);

    const config = CustomSttConfig(
      provider: SttProvider.onDeviceWhisper,
      url: '/tmp/ggml-tiny.bin',
      language: 'en',
      model: 'tiny',
      sendRawAudioToOmi: false,
    );

    final service = TranscriptSocketServiceFactory.createFromCustomConfig(
      16000,
      BleAudioCodec.pcm16,
      'en',
      config,
    );

    expect(service.socket, isNot(isA<CompositeTranscriptionSocket>()));
    expect(service.sttConfigId, config.sttConfigId);
  });

  test('standalone Omi+ speech profile also has no Omi secondary socket', () {
    expect(OmiPlusMode.standalone, isTrue);

    const config = CustomSttConfig(
      provider: SttProvider.onDeviceWhisper,
      url: '/tmp/ggml-tiny.bin',
      language: 'en',
      model: 'tiny',
      sendRawAudioToOmi: false,
    );

    final service = TranscriptSocketServiceFactory.createSpeechProfileOnDevice(
      16000,
      BleAudioCodec.pcm16,
      'en',
      config,
    );

    expect(service.socket, isNot(isA<CompositeTranscriptionSocket>()));
  });
}
