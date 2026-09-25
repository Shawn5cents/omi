import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:omi/utils/logger.dart';

class OmiPlusDriveUpload {
  const OmiPlusDriveUpload({required this.id, required this.name, this.webViewLink});

  final String id;
  final String name;
  final String? webViewLink;
}

/// Google Drive transport for Omi+.
///
/// Google credentials deliberately do not live on the phone. The app sends a
/// bounded object to Grizzy and the NucBox-owned storage endpoint writes it to
/// the user's dedicated Omi+ Drive tree.
class OmiPlusDriveService {
  OmiPlusDriveService._();

  static final instance = OmiPlusDriveService._();

  static const int _maxBinaryBytes = 20 * 1024 * 1024;

  Uri _configuredStorageEndpoint() {
    const baseUrl = String.fromEnvironment('OMI_PLUS_BASE_URL', defaultValue: 'https://omi.nicholsai.com');
    const storageToken = String.fromEnvironment('OMI_PLUS_STORAGE_TOKEN');
    const assistantToken = String.fromEnvironment('OMI_PLUS_ASSISTANT_TOKEN');
    final token = storageToken.isNotEmpty ? storageToken : assistantToken;
    if (token.isEmpty) {
      throw StateError('Omi+ storage credential is not configured in this build');
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/omi/assistant/$token');
  }

  Future<Map<String, dynamic>> _store({
    required String kind,
    required String name,
    required String encoding,
    required Object? payload,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final response = await httpClient
          .post(
            _configuredStorageEndpoint(),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'mode': 'storage',
              'kind': kind,
              'name': name,
              'encoding': encoding,
              'payload': payload,
            }),
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode != 200) {
        throw HttpException('Omi+ Drive bridge failed (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw const FormatException('Invalid Omi+ Drive bridge response');
      }
      return decoded;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  Future<OmiPlusDriveUpload> uploadFile(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxBinaryBytes) {
      throw StateError('Omi+ attachment exceeds 20 MiB');
    }
    final name = file.uri.pathSegments.last;
    final result = await _store(
      kind: 'attachment',
      name: name,
      encoding: 'base64',
      payload: base64Encode(bytes),
    );
    return OmiPlusDriveUpload(
      id: (result['destination'] ?? name).toString(),
      name: (result['name'] ?? name).toString(),
    );
  }

  Future<void> saveJsonObject({
    required String kind,
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    await _store(
      kind: kind,
      name: name,
      encoding: 'json',
      payload: payload,
    );
  }

  Future<void> saveAssistantExchange({
    required String input,
    required String output,
    required String target,
    String source = 'chat',
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final safeTimestamp = now.toIso8601String().replaceAll(':', '-');
      await _store(
        kind: 'conversation',
        name: '$safeTimestamp-$source.json',
        encoding: 'json',
        payload: {
          'schema': 'omi-plus-assistant-exchange-v1',
          'created_at': now.toIso8601String(),
          'source': source,
          'target': target,
          'input': input,
          'output': output,
        },
      );
    } catch (e) {
      // The answer remains usable if Drive is temporarily unavailable. The
      // failure is local-only and never triggers an Omi cloud fallback.
      Logger.debug('Omi+ Drive background save skipped: $e');
    }
  }

  String mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    return 'application/octet-stream';
  }
}
