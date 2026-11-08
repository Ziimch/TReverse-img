// Plain data classes + JSON (de)serialisation. No Flutter dependencies.

enum SearchType { all, exact, products }

extension SearchTypeX on SearchType {
  String get api => switch (this) {
        SearchType.all => 'all',
        SearchType.exact => 'exact_matches',
        SearchType.products => 'products',
      };
  String get label => switch (this) {
        SearchType.all => 'Similar',
        SearchType.exact => 'Exact',
        SearchType.products => 'Products',
      };
}

class VisualMatch {
  final String title;
  final String link;
  final String source;
  final String? thumbnail;
  final String? price;

  const VisualMatch({
    required this.title,
    required this.link,
    required this.source,
    this.thumbnail,
    this.price,
  });

  /// Works for both raw SerpApi items (price is a map) and our own saved JSON
  /// (price is a plain string).
  factory VisualMatch.fromJson(Map<String, dynamic> j) {
    final p = j['price'];
    return VisualMatch(
      title: (j['title'] ?? 'Untitled').toString(),
      link: (j['link'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
      thumbnail: j['thumbnail']?.toString(),
      price: p is Map ? p['value']?.toString() : p?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'source': source,
        'thumbnail': thumbnail,
        'price': price,
      };
}

class LensResult {
  final List<VisualMatch> matches;
  final String? bestGuess;
  final String? bestGuessSub;
  final String? bestGuessLink;

  const LensResult(this.matches,
      {this.bestGuess, this.bestGuessSub, this.bestGuessLink});

  factory LensResult.fromJson(Map<String, dynamic> j) => LensResult(
        ((j['matches'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(VisualMatch.fromJson)
            .toList(),
        bestGuess: j['bestGuess']?.toString(),
        bestGuessSub: j['bestGuessSub']?.toString(),
        bestGuessLink: j['bestGuessLink']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'matches': matches.map((m) => m.toJson()).toList(),
        'bestGuess': bestGuess,
        'bestGuessSub': bestGuessSub,
        'bestGuessLink': bestGuessLink,
      };
}

/// One saved search: a local copy of the image + every result set fetched
/// for it (keyed "type|query"), so reopening costs no API credits.
class HistoryEntry {
  final String id;
  final String imagePath;
  final int createdAt; // millisecondsSinceEpoch
  final String query;
  final Map<String, LensResult> results;

  const HistoryEntry({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    required this.query,
    required this.results,
  });

  String get title {
    for (final r in results.values) {
      if (r.bestGuess != null && r.bestGuess!.isNotEmpty) return r.bestGuess!;
    }
    for (final r in results.values) {
      if (r.matches.isNotEmpty) return r.matches.first.title;
    }
    return 'Untitled search';
  }

  int get totalMatches =>
      results.values.fold(0, (sum, r) => sum + r.matches.length);

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'].toString(),
        imagePath: j['imagePath'].toString(),
        createdAt: (j['createdAt'] as num).toInt(),
        query: (j['query'] ?? '').toString(),
        results: {
          for (final e in ((j['results'] as Map?) ?? const {}).entries)
            e.key.toString():
                LensResult.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'createdAt': createdAt,
        'query': query,
        'results': {for (final e in results.entries) e.key: e.value.toJson()},
      };
}
