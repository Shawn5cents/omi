import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omi/services/omi_plus/omi_plus_outbox.dart';
import 'package:omi/services/omi_plus/omi_plus_reliable_rpc.dart';

void main() {
  late Directory tempDir;
  late OmiPlusOutbox outbox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omi_plus_outbox_test_');
    outbox = OmiPlusOutbox(directory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('successful durable request is removed only after completion', () async {
    var statusReads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/functions/v1/omi-ingress')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'enqueue');
        expect(body['idempotency_key'], 'stable-key-123456');
        expect(request.headers['authorization'], 'Bearer ${'d' * 32}');
        return http.Response(
          jsonEncode({
            'ok': true,
            'job': {'id': '11111111-1111-1111-1111-111111111111', 'status': 'queued'}
          }),
          202,
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/functions/v1/omi-ingress')) {
        statusReads++;
        if (statusReads == 1) {
          return http.Response(
            jsonEncode({
              'ok': true,
              'job': {'status': 'processing', 'attempt_count': 1}
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'job': {
              'status': 'succeeded',
              'attempt_count': 2,
              'result': {
                'ok': true,
                'target': 'auto',
                'agents': ['claude'],
                'text': 'durable answer',
              },
            }
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final rpc = OmiPlusReliableRpc(
      client: client,
      outbox: outbox,
      supabaseBaseUri: Uri.parse('https://supabase.test'),
      deviceToken: 'd' * 32,
      pollInterval: Duration.zero,
      foregroundTimeout: const Duration(seconds: 2),
    );

    final result = await rpc.submitAndWait(
      mode: 'assistant',
      target: 'auto',
      payload: {'text': 'hello'},
      idempotencyKey: 'stable-key-123456',
    );

    expect(result.result['text'], 'durable answer');
    expect(result.attemptCount, 2);
    expect(await outbox.pending(), isEmpty);
  });

  test('network failure keeps request in the local outbox', () async {
    final client = MockClient((_) async => throw const SocketException('offline'));
    final rpc = OmiPlusReliableRpc(
      client: client,
      outbox: outbox,
      supabaseBaseUri: Uri.parse('https://supabase.test'),
      deviceToken: 'd' * 32,
      foregroundTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      rpc.submitAndWait(
        mode: 'assistant',
        target: 'auto',
        payload: {'text': 'save me'},
        idempotencyKey: 'offline-key-123456',
      ),
      throwsA(isA<SocketException>()),
    );

    final pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.idempotencyKey, 'offline-key-123456');
    expect(pending.single.payload['text'], 'save me');
    expect(pending.single.lastError, contains('offline'));
  });
}
