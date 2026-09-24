import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omi/backend/http/api/omi_plus_assistant.dart';
import 'package:omi/models/omi_plus_settings.dart';

void main() {
  test('sends a provider-targeted request and parses the answer', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'ok': true,
          'target': 'chatgpt',
          'agents': ['codex'],
          'text': 'Subscription-backed answer',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final response = await sendOmiPlusAssistant(
      text: '  What did I ask?  ',
      target: OmiPlusAssistantTarget.chatgpt,
      client: client,
      endpoint: Uri.parse('https://example.test/omi/assistant/test-token'),
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/omi/assistant/test-token');
    expect(jsonDecode(captured.body), {'target': 'chatgpt', 'text': 'What did I ask?'});
    expect(response.target, 'chatgpt');
    expect(response.agents, ['codex']);
    expect(response.text, 'Subscription-backed answer');
  });

  test('rejects targets that do not use the subscription bridge', () async {
    final client = MockClient((_) async => http.Response('{}', 500));

    await expectLater(
      sendOmiPlusAssistant(
        text: 'hello',
        target: OmiPlusAssistantTarget.omi,
        client: client,
        endpoint: Uri.parse('https://example.test/assistant'),
      ),
      throwsArgumentError,
    );

    await expectLater(
      sendOmiPlusAssistant(
        text: 'hello',
        target: OmiPlusAssistantTarget.local,
        client: client,
        endpoint: Uri.parse('https://example.test/assistant'),
      ),
      throwsArgumentError,
    );
  });

  test('surfaces bridge failures instead of silently falling back', () async {
    final client = MockClient((_) async => http.Response('{"ok":false}', 503));

    await expectLater(
      sendOmiPlusAssistant(
        text: 'hello',
        target: OmiPlusAssistantTarget.claude,
        client: client,
        endpoint: Uri.parse('https://example.test/assistant'),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
