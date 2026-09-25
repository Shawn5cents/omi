import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OmiPlusOutboxItem {
  const OmiPlusOutboxItem({
    required this.idempotencyKey,
    required this.mode,
    required this.payload,
    required this.createdAt,
    this.target,
    this.jobId,
    this.attemptCount = 0,
    this.lastError,
  });

  final String idempotencyKey;
  final String mode;
  final String? target;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? jobId;
  final int attemptCount;
  final String? lastError;

  OmiPlusOutboxItem copyWith({
    String? jobId,
    int? attemptCount,
    String? lastError,
    bool clearError = false,
  }) {
    return OmiPlusOutboxItem(
      idempotencyKey: idempotencyKey,
      mode: mode,
      target: target,
      payload: payload,
      createdAt: createdAt,
      jobId: jobId ?? this.jobId,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
        'schema': 'omi-plus-outbox-v1',
        'idempotency_key': idempotencyKey,
        'mode': mode,
        'target': target,
        'payload': payload,
        'created_at': createdAt.toUtc().toIso8601String(),
        'job_id': jobId,
        'attempt_count': attemptCount,
        'last_error': lastError,
      };

  factory OmiPlusOutboxItem.fromJson(Map<String, dynamic> json) {
    return OmiPlusOutboxItem(
      idempotencyKey: json['idempotency_key'].toString(),
      mode: json['mode'].toString(),
      target: json['target']?.toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: DateTime.parse(json['created_at'].toString()),
      jobId: json['job_id']?.toString(),
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }
}

class OmiPlusOutbox {
  OmiPlusOutbox({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  Future<Directory> _directory() async {
    final root = _directoryOverride ?? Directory('${(await getApplicationSupportDirectory()).path}/omi_plus/outbox');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  String _safeKey(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<File> _file(String key) async {
    final dir = await _directory();
    return File('${dir.path}/${_safeKey(key)}.json');
  }

  Future<void> put(OmiPlusOutboxItem item) async {
    final file = await _file(item.idempotencyKey);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(item.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<void> remove(String idempotencyKey) async {
    final file = await _file(idempotencyKey);
    if (await file.exists()) await file.delete();
  }

  Future<OmiPlusOutboxItem?> get(String idempotencyKey) async {
    final file = await _file(idempotencyKey);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    return OmiPlusOutboxItem.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<List<OmiPlusOutboxItem>> pending() async {
    final dir = await _directory();
    final items = <OmiPlusOutboxItem>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map) {
          items.add(OmiPlusOutboxItem.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // Keep a corrupt entry on disk for manual recovery instead of silently deleting it.
      }
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }
}
