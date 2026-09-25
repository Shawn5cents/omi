import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:omi/models/omi_plus_settings.dart';
import 'package:omi/services/omi_plus/omi_plus_mode.dart';
import 'package:omi/services/omi_plus/omi_plus_reliable_rpc.dart';

class OmiPlusConversationStructure {
  const OmiPlusConversationStructure({
    required this.title,
    required this.overview,
    required this.emoji,
    required this.category,
    required this.actionItems,
    required this.memories,
  });

  final String title;
  final String overview;
  final String emoji;
  final String category;
  final List<String> actionItems;
  final List<String> memories;

  factory OmiPlusConversationStructure.fromJson(Map<String, dynamic> json) {
    return OmiPlusConversationStructure(
      title: (json['title'] ?? 'Conversation').toString(),
      overview: (json['overview'] ?? '').toString(),
      emoji: (json['emoji'] ?? '🧠').toString(),
      category: (json['category'] ?? 'other').toString(),
      actionItems: (json['action_items'] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      memories: (json['memories'] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
    );
  }
}

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

  if (OmiPlusMode.standalone && endpoint == null) {
    final reliable = OmiPlusReliableRpc(client: client);
    try {
      final completed = await reliable.submitAndWait(
        mode: 'assistant',
        target: target.name,
        payload: {'text': prompt},
      );
      final result = OmiPlusAssistantResponse.fromJson(completed.result);
      if (result.text.trim().isEmpty) {
        throw const FormatException('Omi+ assistant response contained no answer');
      }
      return result;
    } finally {
      reliable.dispose();
    }
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

Future<OmiPlusConversationStructure> processOmiPlusConversation({
  required String transcript,
  OmiPlusAssistantTarget target = OmiPlusAssistantTarget.auto,
  http.Client? client,
  Uri? endpoint,
}) async {
  final text = transcript.trim();
  if (text.isEmpty) throw ArgumentError.value(transcript, 'transcript', 'Transcript cannot be empty');
  if (target == OmiPlusAssistantTarget.omi ||
      target == OmiPlusAssistantTarget.local ||
      target == OmiPlusAssistantTarget.all) {
    throw ArgumentError.value(target, 'target', 'Conversation processing requires one subscription assistant');
  }

  if (OmiPlusMode.standalone && endpoint == null) {
    final reliable = OmiPlusReliableRpc(client: client);
    try {
      final completed = await reliable.submitAndWait(
        mode: 'conversation',
        target: target.name,
        payload: {'transcript': text},
      );
      final structured = completed.result['structured'];
      if (structured is! Map) {
        throw const FormatException('Invalid durable Omi+ conversation response');
      }
      return OmiPlusConversationStructure.fromJson(
        Map<String, dynamic>.from(structured),
      );
    } finally {
      reliable.dispose();
    }
  }

  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final response = await httpClient
        .post(
          endpoint ?? _configuredOmiPlusEndpoint(),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'mode': 'conversation',
            'target': target.name,
            'transcript': text,
          }),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw HttpException('Omi+ conversation bridge failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['structured'] is! Map) {
      throw const FormatException('Invalid Omi+ conversation response');
    }
    return OmiPlusConversationStructure.fromJson(
      Map<String, dynamic>.from(payload['structured'] as Map),
    );
  } finally {
    if (ownsClient) httpClient.close();
  }
}
