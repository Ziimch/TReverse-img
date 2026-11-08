// App state (ChangeNotifiers) + a tiny InheritedWidget for dependency access.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services.dart';

// ───────────────────────── Settings ─────────────────────────

class SettingsController extends ChangeNotifier {
  static const _kSerp = 'serpapi_key';
  static const _kImgbb = 'imgbb_key';
  static const _kTheme = 'theme_mode';

  String serpKey = '';
  String imgbbKey = '';
  ThemeMode themeMode = ThemeMode.system;

  bool get hasKeys => serpKey.isNotEmpty && imgbbKey.isNotEmpty;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    serpKey = p.getString(_kSerp) ?? '';
    imgbbKey = p.getString(_kImgbb) ?? '';
    final t = p.getString(_kTheme);
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == t,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveKeys(String serp, String imgbb) async {
    serpKey = serp.trim();
    imgbbKey = imgbb.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSerp, serpKey);
    await p.setString(_kImgbb, imgbbKey);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, m.name);
  }
}

// ───────────────────────── History ─────────────────────────

class HistoryController extends ChangeNotifier {
  static const maxEntries = 50;

  final HistoryStore store = HistoryStore();
  List<HistoryEntry> entries = [];

  Future<void> load() async {
    entries = await store.load();
  }

  HistoryEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> upsert(HistoryEntry e) async {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      entries[i] = e; // keep position when just refreshing results
    } else {
      entries.insert(0, e);
    }
    while (entries.length > maxEntries) {
      final old = entries.removeLast();
      await store.deleteImage(old.imagePath);
    }
    await store.save(entries);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final e = byId(id);
    if (e == null) return;
    entries.removeWhere((x) => x.id == id);
    await store.deleteImage(e.imagePath);
    await store.save(entries);
    notifyListeners();
  }

  Future<void> clear() async {
    for (final e in entries) {
      await store.deleteImage(e.imagePath);
    }
    entries = [];
    await store.save(entries);
    notifyListeners();
  }
}

// ───────────────────────── Search ─────────────────────────

enum Phase { idle, uploading, searching, done, error }

class LensController extends ChangeNotifier {
  LensController(this.settings, this.history);

  final SettingsController settings;
  final HistoryController history;

  final _picker = ImagePicker();
  final _host = ImageHostService();
  final _lens = LensService();

  Phase phase = Phase.idle;
  File? image;
  String? imageUrl; // temporary public URL (ImgBB)
  SearchType type = SearchType.all;
  String query = '';
  String? error;
  String? _entryId;
  final Map<String, LensResult> _cache = {};

  bool get busy => phase == Phase.uploading || phase == Phase.searching;
  String get _key => '${type.name}|$query';
  LensResult? get current => _cache[_key];

  Future<void> pick(ImageSource source) async {
    if (busy) return;
    try {
      final XFile? f = await _picker.pickImage(
        source: source,
        maxWidth: 1600, // detailed enough, still a quick upload
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (f == null) return; // cancelled
      _setImage(File(f.path));
      await search();
    } on PlatformException catch (e) {
      _fail(
          'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.message ?? e.code}');
    }
  }

  void _setImage(File f) {
    image = f;
    imageUrl = null;
    _entryId = null;
    _cache.clear();
    type = SearchType.all;
    error = null;
  }

  /// Runs (or resumes) upload + search for the current image/tab/query.
  Future<void> search() async {
    if (image == null || busy) return;
    if (!settings.hasKeys) {
      _fail('Add your API keys in Settings to start searching.');
      return;
    }
    error = null;
    try {
      if (!_cache.containsKey(_key)) {
        if (imageUrl == null) {
          phase = Phase.uploading;
          notifyListeners();
          imageUrl = await _host.upload(image!, settings.imgbbKey);
        }
        phase = Phase.searching;
        notifyListeners();
        _cache[_key] = await _lens.search(imageUrl!, settings.serpKey,
            type: type, query: query);
        await _saveHistory();
      }
      phase = Phase.done;
      notifyListeners();
    } on ApiException catch (e) {
      _fail(e.message);
    } on SocketException {
      _fail('No internet connection.');
    } on TimeoutException {
      _fail('The request timed out. Try again.');
    } catch (e) {
      _fail('Unexpected error: $e');
    }
  }

  Future<void> setType(SearchType t) async {
    if (busy || t == type) return;
    type = t;
    await search(); // lazily fetched; cached afterwards
  }

  Future<void> refine(String q) async {
    if (busy) return;
    query = q.trim();
    await search();
  }

  /// Crop to the object of interest — the biggest single accuracy gain.
  Future<void> crop() async {
    if (image == null || busy) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: image!.path,
        compressQuality: 92,
        maxWidth: 1600,
        maxHeight: 1600,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop to the object',
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
        ],
      );
      if (cropped == null) return;
      _setImage(File(cropped.path));
      await search();
    } on PlatformException catch (e) {
      _fail('Could not crop: ${e.message ?? e.code}');
    }
  }

  /// Reopen a saved search without spending any API credits.
  void loadFromHistory(HistoryEntry e) {
    if (busy) return;
    final f = File(e.imagePath);
    if (!f.existsSync()) {
      _fail('The saved image is no longer available.');
      return;
    }
    image = f;
    imageUrl = null;
    _entryId = e.id;
    _cache
      ..clear()
      ..addAll(e.results);
    query = e.query;
    type = SearchType.values.firstWhere(
      (t) => _cache.containsKey('${t.name}|$query'),
      orElse: () => SearchType.all,
    );
    error = null;
    phase = Phase.done;
    notifyListeners();
  }

  void reset() {
    phase = Phase.idle;
    image = null;
    imageUrl = null;
    _entryId = null;
    _cache.clear();
    type = SearchType.all;
    query = '';
    error = null;
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    if (image == null) return;
    try {
      final id = _entryId ?? DateTime.now().microsecondsSinceEpoch.toString();
      final existing = history.byId(id);
      final path =
          existing?.imagePath ?? await history.store.persistImage(image!, id);
      _entryId = id;
      await history.upsert(HistoryEntry(
        id: id,
        imagePath: path,
        createdAt:
            existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        query: query,
        results: Map.of(_cache),
      ));
    } catch (_) {
      // History is best-effort and must never break a search.
    }
  }

  void _fail(String msg) {
    error = msg;
    phase = Phase.error;
    notifyListeners();
  }
}

// ───────────────────────── Scope ─────────────────────────

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.history,
    required this.lens,
    required super.child,
  });

  final SettingsController settings;
  final HistoryController history;
  final LensController lens;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false; // controllers notify themselves
}
