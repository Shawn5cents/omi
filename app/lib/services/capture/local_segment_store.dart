import 'dart:convert';
import 'dart:io';

import 'package:omi/backend/schema/transcript_segment.dart';
import 'package:omi/utils/transcript_hash.dart';
import 'package:path_provider/path_provider.dart';

/// Durable live-caption segments for S21 / S22.
///
/// File-backed JSON under application-support `local_segments/`, not
/// sqflite/Drift — `app/` has no SQLite plugin today and this shard must
/// not add a native dependency. The bytes on disk are the v5 hash payload
/// (speaker, speaker_id, is_user, person_id, text) plus timings/ids S22
/// will need. [release] deletes a session after the projection is accepted.
class LocalSegmentSession {
  const LocalSegmentSession({required this.sessionId, required this.startedAt, required this.segments});

  final String sessionId;
  final DateTime startedAt;
  final List<TranscriptSegment> segments;
}

class LocalSegmentStore {
  LocalSegmentStore._({required this.enabled, Directory? directory}) : _directory = directory;

  factory LocalSegmentStore.disabled() => LocalSegmentStore._(enabled: false);

  factory LocalSegmentStore.at(Directory directory) => LocalSegmentStore._(enabled: true, directory: directory);

  /// Lazy application-support directory. Safe to construct off the first write.
  factory LocalSegmentStore.appSupport() => LocalSegmentStore._(enabled: true);

  static const folderName = 'local_segments';

  final bool enabled;
  Directory? _directory;

  Future<Directory> resolveDirectory() async {
    if (_directory != null) return _directory!;
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/$folderName');
    await dir.create(recursive: true);
    _directory = dir;
    return dir;
  }

  File _fileFor(Directory dir, String sessionId) {
    final safe = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${dir.path}/$safe.json');
  }

  Future<void> replaceSession(String sessionId, List<TranscriptSegment> segments) async {
    if (!enabled) return;
    final dir = await resolveDirectory();
    await dir.create(recursive: true);
    final file = _fileFor(dir, sessionId);
    final tmp = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'encoding_version': transcriptHashEncodingVersion,
      'session_id': sessionId,
      'transcript_sha256': transcriptSha256(segments),
      'segments': segments.map(_segmentToJson).toList(),
    };
    await tmp.writeAsString(jsonEncode(payload));
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  Future<List<TranscriptSegment>> loadSession(String sessionId) async {
    if (!enabled) return const [];
    final dir = await resolveDirectory();
    final file = _fileFor(dir, sessionId);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return const [];
    final raw = decoded['segments'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(_segmentFromJson).toList();
  }

  Future<LocalSegmentSession?> loadLatestSession() async {
    if (!enabled) return null;
    final dir = await resolveDirectory();
    if (!await dir.exists()) return null;
    final files = await dir.list().where((entry) => entry is File && entry.path.endsWith('.json')).cast<File>().toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final file = files.first;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return null;
    final sessionId = decoded['session_id']?.toString();
    final raw = decoded['segments'];
    if (sessionId == null || raw is! List) return null;
    final segments = raw.whereType<Map>().map((row) => _segmentFromJson(Map<String, dynamic>.from(row))).toList();
    return LocalSegmentSession(
      sessionId: sessionId,
      startedAt: await file.lastModified(),
      segments: segments,
    );
  }

  Future<String?> loadDigest(String sessionId) async {
    if (!enabled) return null;
    final dir = await resolveDirectory();
    final file = _fileFor(dir, sessionId);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return null;
    final digest = decoded['transcript_sha256'];
    return digest is String ? digest : null;
  }

  Future<void> release(String sessionId) async {
    if (!enabled) return;
    final dir = await resolveDirectory();
    final file = _fileFor(dir, sessionId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Map<String, Object?> _segmentToJson(TranscriptSegment segment) {
    final kept = canonicalizeTranscriptSegment(segment);
    return {
      'id': segment.id,
      'speaker': kept.speaker,
      'speaker_id': kept.speakerId,
      'is_user': kept.isUser,
      'person_id': kept.personId,
      'text': kept.text,
      'start': segment.start,
      'end': segment.end,
    };
  }

  static TranscriptSegment _segmentFromJson(Map<String, dynamic> json) {
    final kept = canonicalizeSegment(
      speaker: json['speaker'] as String?,
      speakerId: json['speaker_id'] as int?,
      isUser: json['is_user'] as bool?,
      personId: json['person_id'] as String?,
      text: json['text'] as String?,
    );
    final segment = TranscriptSegment(
      id: json['id'] as String? ?? '',
      text: kept.text,
      speaker: kept.speaker,
      speakerId: kept.speakerId,
      isUser: kept.isUser,
      personId: kept.personId,
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
      translations: const [],
    );
    return segment;
  }
}
