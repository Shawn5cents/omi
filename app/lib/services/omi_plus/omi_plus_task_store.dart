import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:omi/backend/schema/action_item.dart';
import 'package:omi/services/omi_plus/omi_plus_drive_service.dart';
import 'package:omi/utils/logger.dart';

class OmiPlusTaskStore {
  OmiPlusTaskStore._();

  static final instance = OmiPlusTaskStore._();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/omi_plus');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/tasks.json');
  }

  Future<List<ActionItemWithMetadata>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final rows = (decoded['items'] as List<dynamic>? ?? const []);
      return rows.whereType<Map<String, dynamic>>().map(ActionItemWithMetadata.fromJson).toList();
    } catch (e) {
      Logger.debug('Omi+ task cache load failed: $e');
      return const [];
    }
  }

  Future<void> save(List<ActionItemWithMetadata> items) async {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'schema': 'omi-plus-tasks-v1',
      'updated_at': now.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };

    try {
      final file = await _file();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    } catch (e) {
      Logger.debug('Omi+ task cache save failed: $e');
    }

    try {
      await OmiPlusDriveService.instance.saveJsonObject(
        kind: 'task',
        name: 'tasks.json',
        payload: payload,
      );
    } catch (e) {
      Logger.debug('Omi+ Drive task mirror skipped: $e');
    }
  }
}
