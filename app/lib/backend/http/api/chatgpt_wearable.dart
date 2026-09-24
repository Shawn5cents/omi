import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:omi/backend/schema/bt_device/bt_device.dart';

class ChatGptWearableResponse {
  final String transcript;
  final String answer;
  final String? responseId;

  const ChatGptWearableResponse({required this.transcript, required this.answer, this.responseId});

  factory ChatGptWearableResponse.fromJson(Map<String, dynamic> json) {
    return ChatGptWearableResponse(
      transcript: (json['transcript'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      responseId: json['response_id']?.toString(),
    );
  }
}

Future<ChatGptWearableResponse> sendChatGptWearableVoice({
  required File file,
  required BleAudioCodec codec,
  String sessionId = 'omi-wearable',
}) async {
  const baseUrl = String.fromEnvironment('OMI_CHATGPT_BASE_URL', defaultValue: 'https://omigpt.nicholsai.com');
  const token = String.fromEnvironment('OMI_CHATGPT_TOKEN');

  if (token.isEmpty) {
    throw StateError('OMI_CHATGPT_TOKEN is not configured in this build');
  }

  final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/ask'))
    ..headers['Authorization'] = 'Bearer $token'
    ..fields['codec'] = codec.toString()
    ..fields['session_id'] = sessionId
    ..files.add(await http.MultipartFile.fromPath('audio', file.path, filename: 'omi.bin'));

  final streamed = await request.send().timeout(const Duration(seconds: 90));
  final response = await http.Response.fromStream(streamed);
  if (response.statusCode != 200) {
    throw HttpException('ChatGPT wearable bridge failed (${response.statusCode})');
  }

  final payload = jsonDecode(response.body);
  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Invalid ChatGPT wearable response');
  }

  final result = ChatGptWearableResponse.fromJson(payload);
  if (result.answer.trim().isEmpty) {
    throw const FormatException('ChatGPT wearable response contained no answer');
  }
  return result;
}
