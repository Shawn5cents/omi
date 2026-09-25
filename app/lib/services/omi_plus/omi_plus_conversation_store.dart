import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/services/omi_plus/omi_plus_drive_service.dart';
import 'package:omi/utils/logger.dart';

class OmiPlusConversationStore {
  OmiPlusConversationStore._();

  static final instance = OmiPlusConversationStore._();

  Future<File> _file() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/omi_plus');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/conversations.json');
  }

  Future<List<ServerConversation>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final rows = (decoded['items'] as List<dynamic>? ?? const []);
      final items = rows.whereType<Map>().map((row) => ServerConversation.fromJson(Map<String, dynamic>.from(row))).toList();
      items.sort((a, b) => (b.startedAt ?? b.createdAt).compareTo(a.startedAt ?? a.createdAt));
      return items;
    } catch (e) {
      Logger.debug('Omi+ conversation cache load failed: $e');
      return const [];
    }
  }

  Future<void> _saveAll(List<ServerConversation> items) async {
    final payload = {
      'schema': 'omi-plus-conversations-v1',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
    final file = await _file();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
  }

  Future<void> upsert(ServerConversation conversation) async {
    final items = await load();
    final index = items.indexWhere((item) => item.id == conversation.id);
    if (index == -1) {
      items.insert(0, conversation);
    } else {
      items[index] = conversation;
    }
    await _saveAll(items);
    try {
      await OmiPlusDriveService.instance.saveJsonObject(
        kind: 'conversation',
        name: '${conversation.id}.json',
        payload: conversation.toJson(),
      );
    } catch (e) {
      Logger.debug('Omi+ conversation Drive mirror skipped: $e');
    }
  }

  Future<void> delete(String id) async {
    final items = await load()..removeWhere((item) => item.id == id);
    await _saveAll(items);
  }
}
