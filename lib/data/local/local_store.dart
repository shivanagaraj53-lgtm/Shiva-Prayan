import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A small document store over [SharedPreferences].
///
/// Documents are JSON maps keyed by `collection/id`, and each collection has a
/// broadcast stream so repositories can expose `watch*` APIs with the same
/// shape Firestore gives them. That symmetry is deliberate: it is what lets
/// the Firestore implementations drop in without any feature code changing.
///
/// This is a real persistence layer, not a stub — writes survive app restarts.
/// What it is *not* is multi-device or server-authoritative, which is exactly
/// the gap `docs/FIREBASE_SETUP.md` closes.
class LocalStore {
  final SharedPreferences _prefs;
  final Map<String, StreamController<List<Map<String, dynamic>>>> _controllers =
      {};

  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String _indexKey(String collection) => 'idx:$collection';
  String _docKey(String collection, String id) => 'doc:$collection/$id';

  List<String> _ids(String collection) =>
      _prefs.getStringList(_indexKey(collection)) ?? const [];

  /// Every document in a collection.
  List<Map<String, dynamic>> readAll(String collection) {
    final documents = <Map<String, dynamic>>[];
    for (final id in _ids(collection)) {
      final raw = _prefs.getString(_docKey(collection, id));
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) documents.add(decoded);
      } on FormatException {
        // A corrupted document must not take down the whole collection; drop
        // it and carry on so the user keeps the rest of their journal.
        continue;
      }
    }
    return documents;
  }

  Map<String, dynamic>? read(String collection, String id) {
    final raw = _prefs.getString(_docKey(collection, id));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Creates or replaces a document. Idempotent on [id], which is what makes a
  /// retried offline write safe (§19).
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> document,
  ) async {
    await _prefs.setString(_docKey(collection, id), jsonEncode(document));
    final ids = [..._ids(collection)];
    if (!ids.contains(id)) {
      ids.add(id);
      await _prefs.setStringList(_indexKey(collection), ids);
    }
    _emit(collection);
  }

  Future<void> delete(String collection, String id) async {
    await _prefs.remove(_docKey(collection, id));
    final ids = [..._ids(collection)]..remove(id);
    await _prefs.setStringList(_indexKey(collection), ids);
    _emit(collection);
  }

  /// Removes an entire collection. Used by account deletion (§4, §28).
  Future<void> clearCollection(String collection) async {
    for (final id in _ids(collection)) {
      await _prefs.remove(_docKey(collection, id));
    }
    await _prefs.remove(_indexKey(collection));
    _emit(collection);
  }

  /// Removes everything this app has stored.
  Future<void> clearAll() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith('doc:') || k.startsWith('idx:'))
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    for (final collection in _controllers.keys) {
      _emit(collection);
    }
  }

  /// A live view of a collection. Emits the current contents immediately.
  Stream<List<Map<String, dynamic>>> watch(String collection) {
    final controller = _controllers.putIfAbsent(
      collection,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );
    // Seed late subscribers on the next microtask so `listen` has returned
    // before the first event arrives.
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(readAll(collection));
    });
    return controller.stream;
  }

  void _emit(String collection) {
    final controller = _controllers[collection];
    if (controller != null && !controller.isClosed) {
      controller.add(readAll(collection));
    }
  }

  /// A single scalar value, for things that are not documents.
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> removeKey(String key) => _prefs.remove(key);

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
  }
}

/// Collection names, in one place so the local store and the Firestore
/// implementation cannot drift apart.
class Collections {
  const Collections._();

  static const profiles = 'profiles';
  static const accounts = 'accounts';
  static const strategies = 'strategies';
  static const checklist = 'checklistItems';
  static const rules = 'rules';
  static const trades = 'trades';
  static const reviews = 'reviews';
  static const psychology = 'psychologyEntries';
  static const behaviourWatches = 'behaviourWatches';
  static const disciplineRecords = 'dailySummaries';
  static const attachments = 'attachments';

  /// Scalar preference keys.
  static const prefsKey = 'appPreferences';
  static const notificationPrefsKey = 'notificationPreferences';
  static const sessionUserKey = 'sessionUser';
}
