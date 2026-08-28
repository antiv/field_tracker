import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../model/transect.dart';

/// Singleton sembast database service — mirrors IsarService API.
/// This is the permanent replacement for IsarService (no native .so deps).
class SembastService with ChangeNotifier {
  static final SembastService _instance = SembastService._internal();

  factory SembastService() => _instance;

  SembastService._internal();

  late Database _db;
  final _store = intMapStoreFactory.store('transects');
  Future<void>? _initFuture;

  /// Safe to call (and await) multiple times — the database is opened once.
  Future<void> init() => _initFuture ??= _openDatabase();

  Future<void> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/herp_tracker.db';
    _db = await databaseFactoryIo.openDatabase(dbPath);
  }

  Database get db => _db;

  // ── CRUD ────────────────────────────────────────────────────────────────

  Future<void> addTransect(Transect transect) async {
    final id = await _store.add(_db, transect.toJson());
    transect.id = id;
  }

  Future<void> updateTransect(Transect transect) async {
    await _store.record(transect.id).put(_db, transect.toJson());
  }

  Future<bool> deleteTransect(Transect transect) async {
    final result = await _store.record(transect.id).delete(_db);
    return result != null;
  }

  Future<List<Transect>> getAllTransects() async {
    final snapshots = await _store.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('startDate', false)]),
    );
    return snapshots.map((s) {
      final json = Map<String, dynamic>.from(s.value);
      json['id'] = s.key;
      return Transect.fromJson(json);
    }).toList();
  }

  /// Transects that were never finished (endDate == null), newest first.
  Future<List<Transect>> getOpenTransects() async {
    final snapshots = await _store.find(
      _db,
      finder: Finder(
        filter: Filter.isNull('endDate'),
        sortOrders: [SortOrder('startDate', false)],
      ),
    );
    return snapshots.map((s) {
      final json = Map<String, dynamic>.from(s.value);
      json['id'] = s.key;
      return Transect.fromJson(json);
    }).toList();
  }

  Future<Transect?> getTransectById(int id) async {
    final snapshot = await _store.record(id).getSnapshot(_db);
    if (snapshot == null) return null;
    final json = Map<String, dynamic>.from(snapshot.value);
    json['id'] = snapshot.key;
    return Transect.fromJson(json);
  }

  // ── Backup / Restore ────────────────────────────────────────────────────

  /// Export all transects as a JSON file and return its path.
  Future<String> createBackupPath() async {
    final transects = await getAllTransects();
    final jsonList = transects.map((t) => t.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final tempDir = await getTemporaryDirectory();
    final backupFile = File('${tempDir.path}/herp_tracker_backup.json');
    await backupFile.writeAsString(jsonString);
    return backupFile.path;
  }

  /// Import transects from a JSON backup file.
  /// Clears existing data before import.
  Future<void> restoreFromJson(String jsonFilePath) async {
    final file = File(jsonFilePath);
    final jsonString = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

    await _db.transaction((txn) async {
      await _store.delete(txn);
      for (final item in jsonList) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as int?;
        if (id != null && id > 0) {
          await _store.record(id).put(txn, map);
        } else {
          await _store.add(txn, map);
        }
      }
    });
    notifyListeners();
  }

  /// Import transects from an Isar-read list (used during migration).
  Future<void> importTransects(List<Transect> transects) async {
    await _db.transaction((txn) async {
      await _store.delete(txn);
      for (final t in transects) {
        final json = t.toJson();
        if (t.id > 0) {
          await _store.record(t.id).put(txn, json);
        } else {
          await _store.add(txn, json);
        }
      }
    });
    notifyListeners();
  }

  Future<bool> hasData() async {
    final count = await _store.count(_db);
    return count > 0;
  }
}
