import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:omi/models/omi_plus_settings.dart';

class OmiPlusAssistantResponse {
  const OmiPlusAssistantResponse({
    required this.target,
    required this.agents,
    required this.text,
  });

  final String target;
  final List<String> agents;
  final String text;

  factory OmiPlusAssistantResponse.fromJson(Map<String, dynamic> json) {
    return OmiPlusAssistantResponse(
      target: (json['target'] ?? '').toString(),
      agents: (json['agents'] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

Uri _configuredOmiPlusEndpoint() {
  const baseUrl = String.fromEnvironment('OMI_PLUS_BASE_URL', defaultValue: 'https://omi.nicholsai.com');
  const token = String.fromEnvironment('OMI_PLUS_ASSISTANT_TOKEN');

  if (token.isEmpty) {
    throw StateError('OMI_PLUS_ASSISTANT_TOKEN is not configured in this build');
  }

  return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/omi/assistant/$token');
}

Future<OmiPlusAssistantResponse> sendOmiPlusAssistant({
  required String text,
  required OmiPlusAssistantTarget target,
  http.Client? client,
  Uri? endpoint,
}) async {
  final prompt = text.trim();
  if (prompt.isEmpty) throw ArgumentError.value(text, 'text', 'Assistant text cannot be empty');
  if (target == OmiPlusAssistantTarget.omi || target == OmiPlusAssistantTarget.local) {
    throw ArgumentError.value(target, 'target', 'Target is not routed through the Grizzy subscription bridge');
  }

  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final response = await httpClient
        .post(
          endpoint ?? _configuredOmiPlusEndpoint(),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'target': target.name, 'text': prompt}),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw HttpException('Omi+ assistant bridge failed (${response.statusCode})');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid Omi+ assistant response');
    }

    final result = OmiPlusAssistantResponse.fromJson(payload);
    if (result.text.trim().isEmpty) {
      throw const FormatException('Omi+ assistant response contained no answer');
    }
    return result;
  } finally {
    if (ownsClient) httpClient.close();
  }
}
