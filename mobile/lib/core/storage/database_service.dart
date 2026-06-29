import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_paths.dart';

/// 本地同步索引数据库（`<appDocs>/.lifescale/sync.db`）。
///
/// Phase 1 建 `sync_meta` + `sync_state`。这里只保存前端同步消费所需状态，
/// 不承载数据库/后端业务建模。
///
/// 开启 WAL + busy_timeout=5000，与桌面端 SQLite 配置一致。
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  factory DatabaseService() => instance;

  Database? _db;

  Future<Database> get() async {
    final cached = _db;
    if (cached != null && cached.isOpen) return cached;
    _db = await openDatabase(
      AppPaths.dbPath,
      version: _version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static const int _version = 2;

  Future<void> _onConfigure(Database db) async {
    // PRAGMA 多数会返回结果行；Android 原生 execSQL（= sqflite execute）会拒绝
    // "会返回行的语句"（报错 "Queries can be performed using SQLiteDatabase query or
    // rawQuery methods only"）。此前对 journal_mode / busy_timeout 用 execute 会直接
    // 抛异常，在 bootstrap 阶段（runApp 之前）崩溃 → 真机白屏。
    // 修正：一律用 rawQuery（对返回/不返回行的语句都安全）；并把 PRAGMA 视为"尽力而为"
    // ——它只是性能优化，失败时回退默认 journal 模式，绝不阻断启动。
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
      await db.rawQuery('PRAGMA busy_timeout = 5000');
    } catch (e) {
      debugPrint('⚠️ SQLite PRAGMA 设置失败（已忽略，回退默认）: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _v1CreateSyncMeta(db);
    await _v2CreateSyncState(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _v2CreateSyncState(db);
    }
  }

  Future<void> _v1CreateSyncMeta(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _v2CreateSyncState(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        vault_path   TEXT PRIMARY KEY,
        local_hash   TEXT,
        synced_hash  TEXT,
        status       TEXT NOT NULL DEFAULT 'clean',
        base_version INTEGER,
        local_mtime  INTEGER,
        updated_at   INTEGER NOT NULL
      )
    ''');
  }

  /// —— sync_meta DAO ——

  Future<String?> metaGet(String key) async {
    final db = await get();
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> metaSet(String key, String value) async {
    final db = await get();
    await db.insert('sync_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertSyncState({
    required String vaultPath,
    required String localHash,
    String? syncedHash,
    required String status,
    int? baseVersion,
    required int localMtime,
    int? updatedAt,
  }) async {
    final db = await get();
    await db.insert('sync_state', {
      'vault_path': vaultPath,
      'local_hash': localHash,
      'synced_hash': syncedHash,
      'status': status,
      'base_version': baseVersion,
      'local_mtime': localMtime,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 列出 sync_state 行。传 [status] 时按状态过滤（'dirty'/'conflict'/'clean'），不传则全表。
  Future<List<Map<String, Object?>>> listSyncState({String? status}) async {
    final db = await get();
    if (status == null || status.isEmpty) {
      return db.query('sync_state', orderBy: 'vault_path ASC');
    }
    return db.query(
      'sync_state',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'vault_path ASC',
    );
  }

  Future<Map<String, Object?>?> getSyncState(String vaultPath) async {
    final db = await get();
    final rows = await db.query(
      'sync_state',
      where: 'vault_path = ?',
      whereArgs: [vaultPath],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> close() async {
    final cached = _db;
    _db = null;
    if (cached != null && cached.isOpen) {
      await cached.close();
    }
  }
}
