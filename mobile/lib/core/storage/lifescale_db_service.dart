import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_paths.dart';

/// 业务真相源库（`<appDocs>/.lifescale/lifescale.db`，docs/09 §6.1）。
///
/// 与同步索引库 `sync.db`（[DatabaseService]）物理分离。结构化生活数据
/// （日程/快速记录/复盘/今日重点）以本库为唯一真相源，沉淀动作生成干净 `.md`
/// 进 `Notes/Daily/`。表前缀 `ls_`、逻辑无外键、软删墓碑、TEXT 存 ISO8601，
/// 与桌面端 `lifescale_db.rs` 1:1 对齐。
class LifescaleDbService {
  LifescaleDbService._();

  static final LifescaleDbService instance = LifescaleDbService._();

  factory LifescaleDbService() => instance;

  Database? _db;

  Future<Database> get() async {
    final cached = _db;
    if (cached != null && cached.isOpen) return cached;
    _db = await openDatabase(
      AppPaths.lifescaleDbPath,
      version: _version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static const int _version = 1;

  Future<void> _onConfigure(Database db) async {
    // PRAGMA 用 rawQuery（与 DatabaseService 一致，规避 Android execSQL 拒绝返回行语句）。
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
      await db.rawQuery('PRAGMA busy_timeout = 5000');
    } catch (e) {
      debugPrint('⚠️ lifescale.db PRAGMA 设置失败（已忽略）: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_schedule (
        id            TEXT PRIMARY KEY,
        date          TEXT NOT NULL,
        start_time    TEXT NOT NULL,
        end_time      TEXT NOT NULL,
        title         TEXT NOT NULL,
        category      TEXT NOT NULL,
        type          TEXT NOT NULL DEFAULT 'task',
        completed     INTEGER NOT NULL DEFAULT 0,
        focus         INTEGER NOT NULL DEFAULT 0,
        sort_order    INTEGER NOT NULL DEFAULT 0,
        settled       INTEGER NOT NULL DEFAULT 0,
        source_device TEXT,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        deleted       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedule_date ON ls_schedule(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedule_settled ON ls_schedule(settled)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedule_updated ON ls_schedule(updated_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_quick_note (
        id            TEXT PRIMARY KEY,
        date          TEXT NOT NULL,
        content       TEXT NOT NULL,
        source_device TEXT,
        settled       INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        deleted       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quick_note_date ON ls_quick_note(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quick_note_settled ON ls_quick_note(settled)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_review_answer (
        id           TEXT PRIMARY KEY,
        date         TEXT NOT NULL,
        question_id  TEXT NOT NULL,
        title        TEXT NOT NULL,
        content      TEXT NOT NULL DEFAULT '',
        settled      INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        deleted      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_review_answer_date ON ls_review_answer(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_review_answer_question ON ls_review_answer(question_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_review_scheme (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        source     TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active  INTEGER NOT NULL DEFAULT 0,
        payload    TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_daily_focus (
        date       TEXT PRIMARY KEY,
        content    TEXT,
        settled    INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ls_daily_settlement (
        date            TEXT PRIMARY KEY,
        md_content_hash TEXT NOT NULL,
        md_vault_path   TEXT NOT NULL,
        settled_at      TEXT NOT NULL,
        settled_by      TEXT NOT NULL
      )
    ''');
  }

  // ============================ Row 类型 ============================

  static ScheduleRow mapSchedule(Map<String, Object?> r) => ScheduleRow(
        id: r['id'] as String,
        date: r['date'] as String,
        startTime: r['start_time'] as String,
        endTime: r['end_time'] as String,
        title: r['title'] as String,
        category: r['category'] as String,
        type: r['type'] as String,
        completed: (r['completed'] as int) != 0,
        focus: (r['focus'] as int) != 0,
        sortOrder: r['sort_order'] as int,
        settled: (r['settled'] as int) != 0,
        sourceDevice: r['source_device'] as String?,
        createdAt: r['created_at'] as String,
        updatedAt: r['updated_at'] as String,
        deleted: (r['deleted'] as int) != 0,
      );

  static QuickNoteRow mapQuickNote(Map<String, Object?> r) => QuickNoteRow(
        id: r['id'] as String,
        date: r['date'] as String,
        content: r['content'] as String,
        sourceDevice: r['source_device'] as String?,
        settled: (r['settled'] as int) != 0,
        createdAt: r['created_at'] as String,
        updatedAt: r['updated_at'] as String,
        deleted: (r['deleted'] as int) != 0,
      );

  static ReviewAnswerRow mapReviewAnswer(Map<String, Object?> r) => ReviewAnswerRow(
        id: r['id'] as String,
        date: r['date'] as String,
        questionId: r['question_id'] as String,
        title: r['title'] as String,
        content: r['content'] as String,
        settled: (r['settled'] as int) != 0,
        createdAt: r['created_at'] as String,
        updatedAt: r['updated_at'] as String,
        deleted: (r['deleted'] as int) != 0,
      );

  static DailyFocusRow? mapDailyFocus(Map<String, Object?> r) => DailyFocusRow(
        date: r['date'] as String,
        content: r['content'] as String?,
        settled: (r['settled'] as int) != 0,
        updatedAt: r['updated_at'] as String,
      );

  // ============================ ls_schedule ============================

  Future<void> upsertSchedule(ScheduleRow row) async {
    final db = await get();
    await db.insert('ls_schedule', row.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScheduleRow>> listSchedulesByDate(String date, {bool includeDeleted = false}) async {
    final db = await get();
    final where = includeDeleted ? 'date = ?' : 'date = ? AND deleted = 0';
    final rows = await db.query('ls_schedule',
        where: where, whereArgs: [date], orderBy: 'sort_order ASC, start_time ASC');
    return rows.map(mapSchedule).toList();
  }

  Future<void> softDeleteSchedulesByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_schedule SET deleted = 1, updated_at = ? WHERE date = ? AND deleted = 0',
      [now, date],
    );
  }

  Future<void> markSchedulesSettledByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_schedule SET settled = 1, updated_at = ? WHERE date = ? AND settled = 0',
      [now, date],
    );
  }

  Future<List<ScheduleRow>> listAllUnsettledSchedules() async {
    final db = await get();
    final rows = await db.query('ls_schedule',
        where: 'settled = 0 AND deleted = 0', orderBy: 'updated_at ASC');
    return rows.map(mapSchedule).toList();
  }

  // ============================ ls_quick_note ============================

  Future<void> upsertQuickNote(QuickNoteRow row) async {
    final db = await get();
    await db.insert('ls_quick_note', row.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<QuickNoteRow>> listQuickNotesByDate(String date, {bool includeDeleted = false}) async {
    final db = await get();
    final where = includeDeleted ? 'date = ?' : 'date = ? AND deleted = 0';
    final rows = await db.query('ls_quick_note',
        where: where, whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(mapQuickNote).toList();
  }

  Future<void> softDeleteQuickNotesByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_quick_note SET deleted = 1, updated_at = ? WHERE date = ? AND deleted = 0',
      [now, date],
    );
  }

  Future<void> markQuickNotesSettledByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_quick_note SET settled = 1, updated_at = ? WHERE date = ? AND settled = 0',
      [now, date],
    );
  }

  Future<List<QuickNoteRow>> listAllUnsettledQuickNotes() async {
    final db = await get();
    final rows = await db.query('ls_quick_note',
        where: 'settled = 0 AND deleted = 0', orderBy: 'updated_at ASC');
    return rows.map(mapQuickNote).toList();
  }

  // ============================ ls_review_answer ============================

  Future<void> upsertReviewAnswer(ReviewAnswerRow row) async {
    final db = await get();
    await db.insert('ls_review_answer', row.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewAnswerRow>> listReviewAnswersByDate(String date, {bool includeDeleted = false}) async {
    final db = await get();
    final where = includeDeleted ? 'date = ?' : 'date = ? AND deleted = 0';
    final rows = await db.query('ls_review_answer',
        where: where, whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(mapReviewAnswer).toList();
  }

  Future<void> softDeleteReviewAnswersByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_review_answer SET deleted = 1, updated_at = ? WHERE date = ? AND deleted = 0',
      [now, date],
    );
  }

  Future<void> markReviewAnswersSettledByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_review_answer SET settled = 1, updated_at = ? WHERE date = ? AND settled = 0',
      [now, date],
    );
  }

  Future<List<ReviewAnswerRow>> listAllUnsettledReviewAnswers() async {
    final db = await get();
    final rows = await db.query('ls_review_answer',
        where: 'settled = 0 AND deleted = 0', orderBy: 'updated_at ASC');
    return rows.map(mapReviewAnswer).toList();
  }

  // ============================ ls_daily_focus ============================

  Future<DailyFocusRow?> getDailyFocus(String date) async {
    final db = await get();
    final rows = await db.query('ls_daily_focus', where: 'date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : mapDailyFocus(rows.first);
  }

  Future<void> upsertDailyFocus(DailyFocusRow row) async {
    final db = await get();
    await db.insert('ls_daily_focus', row.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markDailyFocusSettledByDate(String date, String now) async {
    final db = await get();
    await db.rawUpdate(
      'UPDATE ls_daily_focus SET settled = 1, updated_at = ? WHERE date = ? AND settled = 0',
      [now, date],
    );
  }

  Future<List<DailyFocusRow>> listAllUnsettledDailyFocus() async {
    final db = await get();
    final rows = await db.query('ls_daily_focus', where: 'settled = 0', orderBy: 'updated_at ASC');
    return rows.map(mapDailyFocus).whereType<DailyFocusRow>().toList();
  }

  // ============================ ls_daily_settlement ============================

  Future<SettlementRow?> getSettlement(String date) async {
    final db = await get();
    final rows = await db.query('ls_daily_settlement', where: 'date = ?', whereArgs: [date], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return SettlementRow(
      date: r['date'] as String,
      mdContentHash: r['md_content_hash'] as String,
      mdVaultPath: r['md_vault_path'] as String,
      settledAt: r['settled_at'] as String,
      settledBy: r['settled_by'] as String,
    );
  }

  Future<void> upsertSettlement(SettlementRow row) async {
    final db = await get();
    await db.insert('ls_daily_settlement', row.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<String>> listUnsettledPastDates(String today) async {
    final db = await get();
    final rows = await db.rawQuery(
      '''SELECT DISTINCT date FROM ls_schedule WHERE date < ? AND settled = 0 AND deleted = 0
         UNION
         SELECT DISTINCT date FROM ls_quick_note WHERE date < ? AND settled = 0 AND deleted = 0
         UNION
         SELECT DISTINCT date FROM ls_review_answer WHERE date < ? AND settled = 0 AND deleted = 0
         UNION
         SELECT date FROM ls_daily_focus WHERE date < ? AND settled = 0
         ORDER BY date ASC''',
      [today, today, today, today],
    );
    return rows.map((r) => r['date'] as String).toList();
  }

  Future<List<String>> listSettledDatesInMonth(String yearMonth) async {
    final db = await get();
    final rows = await db.rawQuery(
      "SELECT date FROM ls_daily_settlement WHERE date LIKE ? ORDER BY date ASC",
      ['$yearMonth%'],
    );
    return rows.map((r) => r['date'] as String).toList();
  }

  Future<void> close() async {
    final cached = _db;
    _db = null;
    if (cached != null && cached.isOpen) {
      await cached.close();
    }
  }
}

// ============================ Row 数据类 ============================

class ScheduleRow {
  ScheduleRow({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.category,
    required this.type,
    required this.completed,
    required this.focus,
    required this.sortOrder,
    required this.settled,
    this.sourceDevice,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final String date;
  final String startTime;
  final String endTime;
  final String title;
  final String category;
  final String type;
  final bool completed;
  final bool focus;
  final int sortOrder;
  final bool settled;
  final String? sourceDevice;
  final String createdAt;
  final String updatedAt;
  final bool deleted;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'title': title,
        'category': category,
        'type': type,
        'completed': completed ? 1 : 0,
        'focus': focus ? 1 : 0,
        'sort_order': sortOrder,
        'settled': settled ? 1 : 0,
        'source_device': sourceDevice,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
      };
}

class QuickNoteRow {
  QuickNoteRow({
    required this.id,
    required this.date,
    required this.content,
    this.sourceDevice,
    required this.settled,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final String date;
  final String content;
  final String? sourceDevice;
  final bool settled;
  final String createdAt;
  final String updatedAt;
  final bool deleted;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'content': content,
        'source_device': sourceDevice,
        'settled': settled ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
      };
}

class ReviewAnswerRow {
  ReviewAnswerRow({
    required this.id,
    required this.date,
    required this.questionId,
    required this.title,
    required this.content,
    required this.settled,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final String date;
  final String questionId;
  final String title;
  final String content;
  final bool settled;
  final String createdAt;
  final String updatedAt;
  final bool deleted;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'question_id': questionId,
        'title': title,
        'content': content,
        'settled': settled ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
      };
}

class DailyFocusRow {
  DailyFocusRow({
    required this.date,
    this.content,
    required this.settled,
    required this.updatedAt,
  });

  final String date;
  final String? content;
  final bool settled;
  final String updatedAt;

  Map<String, Object?> toMap() => {
        'date': date,
        'content': content,
        'settled': settled ? 1 : 0,
        'updated_at': updatedAt,
      };
}

class SettlementRow {
  SettlementRow({
    required this.date,
    required this.mdContentHash,
    required this.mdVaultPath,
    required this.settledAt,
    required this.settledBy,
  });

  final String date;
  final String mdContentHash;
  final String mdVaultPath;
  final String settledAt;
  final String settledBy;

  Map<String, Object?> toMap() => {
        'date': date,
        'md_content_hash': mdContentHash,
        'md_vault_path': mdVaultPath,
        'settled_at': settledAt,
        'settled_by': settledBy,
      };
}
