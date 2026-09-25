import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:omi/backend/http/api/omi_plus_assistant.dart';
import 'package:omi/backend/schema/conversation.dart';
import 'package:omi/backend/schema/structured.dart';
import 'package:omi/models/omi_plus_settings.dart';
import 'package:omi/services/capture/local_segment_store.dart';
import 'package:omi/services/omi_plus/omi_plus_conversation_store.dart';
import 'package:omi/services/omi_plus/omi_plus_drive_service.dart';
import 'package:omi/utils/logger.dart';

class OmiPlusConversationProcessor {
  OmiPlusConversationProcessor({
    required this.localSegments,
    OmiPlusConversationStore? store,
  }) : store = store ?? OmiPlusConversationStore.instance;

  final LocalSegmentStore localSegments;
  final OmiPlusConversationStore store;

  Future<CreateConversationResponse?> processLatest() async {
    final latest = await localSegments.loadLatestSession();
    if (latest == null || latest.segments.isEmpty) return null;

    final transcript = latest.segments.map((segment) => segment.text.trim()).where((text) => text.isNotEmpty).join('\n');
    if (transcript.isEmpty) return null;

    OmiPlusConversationStructure structure;
    try {
      structure = await processOmiPlusConversation(
        transcript: transcript,
        target: OmiPlusAssistantTarget.auto,
      );
    } catch (e) {
      Logger.debug('Omi+ structured conversation fallback: $e');
      final first = transcript.split(RegExp(r'[.!?\n]')).first.trim();
      structure = OmiPlusConversationStructure(
        title: first.isEmpty ? 'Conversation' : first.substring(0, first.length.clamp(0, 80)),
        overview: transcript.length > 2000 ? transcript.substring(0, 2000) : transcript,
        emoji: '🧠',
        category: 'other',
        actionItems: const [],
        memories: const [],
      );
    }

    final now = DateTime.now().toUtc();
    final conversation = ServerConversation(
      id: 'omi-plus-${now.microsecondsSinceEpoch}',
      createdAt: now,
      startedAt: latest.startedAt,
      finishedAt: now,
      structured: Structured(
        structure.title,
        structure.overview,
        emoji: structure.emoji,
        category: structure.category,
      )..actionItems = structure.actionItems.map(ActionItem.new).toList(),
      transcriptSegments: latest.segments,
      source: ConversationSource.omi,
      status: ConversationStatus.completed,
    );

    await store.upsert(conversation);
    await localSegments.release(latest.sessionId);

    if (structure.memories.isNotEmpty) {
      await OmiPlusDriveService.instance.saveJsonObject(
        kind: 'memory',
        name: '${conversation.id}-memories.json',
        payload: {
          'schema': 'omi-plus-memories-v1',
          'conversation_id': conversation.id,
          'created_at': now.toIso8601String(),
          'memories': structure.memories,
        },
      ).catchError((Object e) {
        Logger.debug('Omi+ memory Drive mirror skipped: $e');
      });
    }

    return CreateConversationResponse(messages: const [], conversation: conversation);
  }
}
