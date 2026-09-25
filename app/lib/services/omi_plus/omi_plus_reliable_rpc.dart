import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:omi/services/omi_plus/omi_plus_outbox.dart';

class OmiPlusRecoveredResult {
  const OmiPlusRecoveredResult({required this.item, required this.result});

  final OmiPlusOutboxItem item;
  final Map<String, dynamic> result;
}

class OmiPlusReliableResult {
  const OmiPlusReliableResult({
    required this.jobId,
    required this.result,
    required this.attemptCount,
  });

  final String jobId;
  final Map<String, dynamic> result;
  final int attemptCount;
}

class OmiPlusReliableRpc {
  OmiPlusReliableRpc({
    http.Client? client,
    OmiPlusOutbox? outbox,
    Uri? supabaseBaseUri,
    String? deviceToken,
    Duration? pollInterval,
    Duration? foregroundTimeout,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _outbox = outbox ?? OmiPlusOutbox(),
        _supabaseBaseUri = supabaseBaseUri ??
            Uri.parse(const String.fromEnvironment(
              'OMI_PLUS_SUPABASE_URL',
              defaultValue: 'https://vndrhuixllqtuakdrqkm.supabase.co',
            )),
        _deviceToken = deviceToken ?? const String.fromEnvironment('OMI_PLUS_ASSISTANT_TOKEN'),
        pollInterval = pollInterval ?? const Duration(milliseconds: 650),
        foregroundTimeout = foregroundTimeout ?? const Duration(seconds: 60);

  final http.Client _client;
  final bool _ownsClient;
  final OmiPlusOutbox _outbox;
  final Uri _supabaseBaseUri;
  final String _deviceToken;
  final Duration pollInterval;
  final Duration foregroundTimeout;

  Uri get _ingress => _supabaseBaseUri.replace(path: '/functions/v1/omi-ingress');

  Map<String, String> get _headers => {
        'authorization': 'Bearer $_deviceToken',
        'content-type': 'application/json',
      };

  Future<Map<String, dynamic>> _postGateway(Map<String, dynamic> body) async {
    if (_deviceToken.length < 24) {
      throw StateError('Omi+ device credential is not configured');
    }

    final response = await _client
        .post(_ingress, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    final decoded = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Omi+ reliability gateway failed (${response.statusCode})');
    }
    if (decoded is! Map) {
      throw const FormatException('Invalid Omi+ reliability response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _getStatus(String jobId) async {
    if (_deviceToken.length < 24) {
      throw StateError('Omi+ device credential is not configured');
    }
    final uri = _ingress.replace(queryParameters: {'job_id': jobId});
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    final decoded = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Omi+ status gateway failed (${response.statusCode})');
    }
    if (decoded is! Map) throw const FormatException('Invalid Omi+ status response');
    final job = decoded['job'];
    if (job is! Map) throw const FormatException('Omi+ status response contained no job');
    return Map<String, dynamic>.from(job);
  }

  Future<List<OmiPlusRecoveredResult>> recoverPending() async {
    final recovered = <OmiPlusRecoveredResult>[];
    final pending = await _outbox.pending();

    for (var item in pending) {
      try {
        var jobId = item.jobId;
        if (jobId == null || jobId.isEmpty) {
          final enqueue = await _postGateway({
            'action': 'enqueue',
            'idempotency_key': item.idempotencyKey,
            'mode': item.mode,
            'target': item.target,
            'payload': item.payload,
          });
          jobId = enqueue['job_id']?.toString() ?? (enqueue['job'] is Map ? (enqueue['job'] as Map)['id']?.toString() : null);
          if (jobId == null || jobId.isEmpty) continue;
          item = item.copyWith(jobId: jobId, clearError: true);
          await _outbox.put(item);
        }

        final status = await _getStatus(jobId);
        final state = status['status']?.toString();
        if (state == 'succeeded' && status['result'] is Map) {
          final result = Map<String, dynamic>.from(status['result'] as Map);
          recovered.add(OmiPlusRecoveredResult(item: item, result: result));
          await _outbox.remove(item.idempotencyKey);
        } else if (state == 'failed') {
          await _outbox.put(item.copyWith(lastError: status['error']?.toString() ?? 'Omi+ job failed'));
        }
      } catch (_) {
        // Leave the durable outbox entry in place. A later recovery tick retries it.
      }
    }

    return recovered;
  }

  Future<OmiPlusReliableResult> submitAndWait({
    required String mode,
    required Map<String, dynamic> payload,
    String? target,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? const Uuid().v4();
    var item = OmiPlusOutboxItem(
      idempotencyKey: key,
      mode: mode,
      target: target,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );

    await _outbox.put(item);

    try {
      final enqueue = await _postGateway({
        'action': 'enqueue',
        'idempotency_key': key,
        'mode': mode,
        'target': target,
        'payload': payload,
      });
      final jobId = enqueue['job_id']?.toString() ?? (enqueue['job'] is Map ? (enqueue['job'] as Map)['id']?.toString() : null);
      if (jobId == null || jobId.isEmpty) {
        throw const FormatException('Omi+ queue returned no job id');
      }

      item = item.copyWith(
        jobId: jobId,
        attemptCount: item.attemptCount + 1,
        clearError: true,
      );
      await _outbox.put(item);

      final deadline = DateTime.now().add(foregroundTimeout);
      while (DateTime.now().isBefore(deadline)) {
        final status = await _getStatus(jobId);
        final state = status['status']?.toString();
        if (state == 'succeeded') {
          final raw = status['result'];
          if (raw is! Map) {
            throw const FormatException('Omi+ job completed without a result');
          }
          await _outbox.remove(key);
          return OmiPlusReliableResult(
            jobId: jobId,
            result: Map<String, dynamic>.from(raw),
            attemptCount: (status['attempt_count'] as num?)?.toInt() ?? item.attemptCount,
          );
        }
        if (state == 'failed') {
          final error = status['error']?.toString() ?? 'Omi+ job failed';
          item = item.copyWith(lastError: error);
          await _outbox.put(item);
          throw StateError(error);
        }
        await Future<void>.delayed(pollInterval);
      }

      item = item.copyWith(lastError: 'Queued for retry; foreground wait expired');
      await _outbox.put(item);
      throw TimeoutException('Omi+ request is safely queued and still processing');
    } catch (error) {
      item = item.copyWith(
        attemptCount: item.attemptCount + (item.jobId == null ? 1 : 0),
        lastError: error.toString(),
      );
      await _outbox.put(item);
      rethrow;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
