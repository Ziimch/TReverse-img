// Network + persistence layer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> _decode(String s) {
  try {
    final d = jsonDecode(s);
    return d is Map<String, dynamic> ? d : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// SerpApi's Google Lens engine only accepts an image *URL*, so we first push
/// the picture to ImgBB. `expiration=600` auto-deletes it after 10 minutes.
class ImageHostService {
  Future<String> upload(File file, String apiKey) async {
    final bytes = await file.readAsBytes();
    final res = await http
        .post(
          Uri.parse('https://api.imgbb.com/1/upload')
              .replace(queryParameters: {'key': apiKey, 'expiration': '600'}),
          body: {'image': base64Encode(bytes)},
        )
        .timeout(const Duration(seconds: 60));

    final body = _decode(res.body);
    if (res.statusCode != 200 || body['data'] == null) {
      final msg = (body['error'] is Map) ? body['error']['message'] : null;
      throw ApiException(
          'Image upload failed: ${msg ?? 'HTTP ${res.statusCode}'}');
    }
    return body['data']['url'].toString();
  }
}

class LensService {
  Future<LensResult> search(
    String imageUrl,
    String apiKey, {
    required SearchType type,
    String? query,
  }) async {
    // Locale-aware results are noticeably more relevant.
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final country = locale.countryCode;
    final q = (query ?? '').trim();

    final uri = Uri.https('serpapi.com', '/search.json', {
      'engine': 'google_lens',
      'url': imageUrl,
      'api_key': apiKey,
      'type': type.api,
      'hl': locale.languageCode,
      if (country != null && country.isNotEmpty) 'country': country.toLowerCase(),
      // Text refinement ("multisearch") isn't supported by exact_matches.
      if (q.isNotEmpty && type != SearchType.exact) 'q': q,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 90));
    final body = _decode(res.body);

    if (body['error'] != null) {
      final err = body['error'].toString();
      if (err.toLowerCase().contains("hasn't returned any results")) {
        return const LensResult([]); // empty result, not a failure
      }
      throw ApiException('SerpApi: $err');
    }
    if (res.statusCode != 200) {
      throw ApiException('SerpApi returned HTTP ${res.statusCode}');
    }

    final seen = <String>{};
    final matches = <VisualMatch>[];
    for (final key in const ['exact_matches', 'visual_matches']) {
      for (final raw in (body[key] as List?) ?? const []) {
        if (raw is! Map<String, dynamic>) continue;
        final m = VisualMatch.fromJson(raw);
        if (m.link.isEmpty ||
            m.link.contains('ibb.co') ||
            m.link.contains('imgbb')) {
          continue;
        }
        if (seen.add(m.link)) matches.add(m);
      }
    }

    String? t, sub, link;
    final kg = body['knowledge_graph'];
    if (kg is List && kg.isNotEmpty && kg.first is Map) {
      final k = kg.first as Map;
      t = k['title']?.toString();
      sub = k['subtitle']?.toString();
      link = k['link']?.toString();
    }
    return LensResult(matches,
        bestGuess: t, bestGuessSub: sub, bestGuessLink: link);
  }
}

/// Persists history JSON in SharedPreferences and image copies in the app's
/// documents directory.
class HistoryStore {
  static const _k = 'history_v1';

  Future<List<HistoryEntry>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_k);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return []; // corrupted data should never crash the app
    }
  }

  Future<void> save(List<HistoryEntry> entries) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<String> persistImage(File src, String id) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/history');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = File('${dir.path}/$id.jpg');
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> deleteImage(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
