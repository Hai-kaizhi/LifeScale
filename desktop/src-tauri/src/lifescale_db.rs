//! 业务真相源库：`<vault>/.lifescale/lifescale.db`（SQLite）。
//!
//! docs/09《Daily 沉淀分层与 SQL 真相源架构方案》现行架构：结构化生活数据
//! （日程 / 快速记录 / 复盘答案 / 今日重点）以本地 SQLite 为唯一真相源，
//! 与同步索引库 `sync.db`（`<vault>/.lifescale/sync.db`）物理分离。
//!
//! 约定（与后端 V1 一致）：
//! - 表前缀 `ls_`，逻辑关联不用外键
//! - 软删除墓碑：`deleted = 1`，不物理删除
//! - 时间字段 TEXT 存 ISO8601（前端 dayjs 写入）
//! - 当天数据 `settled = 0`；沉淀后置 `settled = 1`（docs/09 第七章）

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

// ============================ 行结构体（serde camelCase，供前端 invoke）============================

/// 日程行（任务 + 时间记录）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleRow {
    pub id: String,
    pub date: String,
    pub start_time: String,
    pub end_time: String,
    pub title: String,
    /// '工作' | '生活'
    pub category: String,
    /// 'task' | 'note'
    #[serde(rename = "type")]
    pub schedule_type: String,
    pub completed: bool,
    pub focus: bool,
    pub sort_order: i64,
    pub settled: bool,
    pub source_device: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub deleted: bool,
}

/// 快速记录行。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QuickNoteRow {
    pub id: String,
    pub date: String,
    pub content: String,
    pub source_device: Option<String>,
    pub settled: bool,
    pub created_at: String,
    pub updated_at: String,
    pub deleted: bool,
}

/// 复盘答案行（每题一条）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewAnswerRow {
    pub id: String,
    pub date: String,
    pub question_id: String,
    pub title: String,
    pub content: String,
    pub settled: bool,
    pub created_at: String,
    pub updated_at: String,
    pub deleted: bool,
}

/// 复盘方案行（本地副本，可离线编辑）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewSchemeRow {
    pub id: String,
    pub name: String,
    /// 'official' | 'custom'
    pub source: String,
    pub is_default: bool,
    pub is_active: bool,
    /// JSON：questions 数组
    pub payload: String,
    pub updated_at: String,
}

/// 今日重点行（自由文本，单条/日；日程类重点由 ls_schedule.focus 表达）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyFocusRow {
    pub date: String,
    pub content: Option<String>,
    pub settled: bool,
    pub updated_at: String,
}

/// 沉淀记录行（docs/09 §6.1.3 对账核心）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettlementRow {
    pub date: String,
    pub md_content_hash: String,
    pub md_vault_path: String,
    pub settled_at: String,
    /// 'manual' | 'lazy-backfill' | device_id
    pub settled_by: String,
}

// ============================ 打开 + 建表 ============================

/// 打开（必要时创建）`<root>/.lifescale/lifescale.db`，建表，开 WAL + busy_timeout。
pub fn open(root: &Path) -> Result<Connection, String> {
    let dir: PathBuf = root.join(".lifescale");
    std::fs::create_dir_all(&dir).map_err(|e| format!("创建 .lifescale 失败: {e}"))?;
    let db_path = dir.join("lifescale.db");
    let conn = Connection::open(&db_path).map_err(|e| format!("打开 lifescale.db 失败: {e}"))?;
    conn.pragma_update(None, "journal_mode", "WAL")
        .map_err(|e| e.to_string())?;
    conn.pragma_update(None, "busy_timeout", 5000)
        .map_err(|e| e.to_string())?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS ls_schedule (
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
        );
        CREATE INDEX IF NOT EXISTS idx_schedule_date ON ls_schedule(date);
        CREATE INDEX IF NOT EXISTS idx_schedule_settled ON ls_schedule(settled);
        CREATE INDEX IF NOT EXISTS idx_schedule_updated ON ls_schedule(updated_at);

        CREATE TABLE IF NOT EXISTS ls_quick_note (
            id            TEXT PRIMARY KEY,
            date          TEXT NOT NULL,
            content       TEXT NOT NULL,
            source_device TEXT,
            settled       INTEGER NOT NULL DEFAULT 0,
            created_at    TEXT NOT NULL,
            updated_at    TEXT NOT NULL,
            deleted       INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_quick_note_date ON ls_quick_note(date);
        CREATE INDEX IF NOT EXISTS idx_quick_note_settled ON ls_quick_note(settled);

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
        );
        CREATE INDEX IF NOT EXISTS idx_review_answer_date ON ls_review_answer(date);
        CREATE INDEX IF NOT EXISTS idx_review_answer_question ON ls_review_answer(question_id);

        CREATE TABLE IF NOT EXISTS ls_review_scheme (
            id         TEXT PRIMARY KEY,
            name       TEXT NOT NULL,
            source     TEXT NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0,
            is_active  INTEGER NOT NULL DEFAULT 0,
            payload    TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ls_daily_focus (
            date       TEXT PRIMARY KEY,
            content    TEXT,
            settled    INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ls_daily_settlement (
            date            TEXT PRIMARY KEY,
            md_content_hash TEXT NOT NULL,
            md_vault_path   TEXT NOT NULL,
            settled_at      TEXT NOT NULL,
            settled_by      TEXT NOT NULL
        );",
    )
    .map_err(|e| e.to_string())?;
    Ok(conn)
}

// ============================ ls_schedule ============================

pub fn upsert_schedule(conn: &Connection, row: &ScheduleRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_schedule
            (id, date, start_time, end_time, title, category, type, completed, focus, sort_order, settled, source_device, created_at, updated_at, deleted)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)
         ON CONFLICT(id) DO UPDATE SET
            date = excluded.date,
            start_time = excluded.start_time,
            end_time = excluded.end_time,
            title = excluded.title,
            category = excluded.category,
            type = excluded.type,
            completed = excluded.completed,
            focus = excluded.focus,
            sort_order = excluded.sort_order,
            settled = excluded.settled,
            source_device = excluded.source_device,
            updated_at = excluded.updated_at,
            deleted = excluded.deleted",
        params![
            row.id,
            row.date,
            row.start_time,
            row.end_time,
            row.title,
            row.category,
            row.schedule_type,
            row.completed as i64,
            row.focus as i64,
            row.sort_order,
            row.settled as i64,
            row.source_device,
            row.created_at,
            row.updated_at,
            row.deleted as i64,
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

fn map_schedule_row(r: &rusqlite::Row) -> rusqlite::Result<ScheduleRow> {
    Ok(ScheduleRow {
        id: r.get(0)?,
        date: r.get(1)?,
        start_time: r.get(2)?,
        end_time: r.get(3)?,
        title: r.get(4)?,
        category: r.get(5)?,
        schedule_type: r.get(6)?,
        completed: r.get::<_, i64>(7)? != 0,
        focus: r.get::<_, i64>(8)? != 0,
        sort_order: r.get(9)?,
        settled: r.get::<_, i64>(10)? != 0,
        source_device: r.get(11)?,
        created_at: r.get(12)?,
        updated_at: r.get(13)?,
        deleted: r.get::<_, i64>(14)? != 0,
    })
}

/// 列出某天的日程（默认排除软删墓碑；include_deleted=true 时含墓碑）。
pub fn list_schedules_by_date(
    conn: &Connection,
    date: &str,
    include_deleted: bool,
) -> Result<Vec<ScheduleRow>, String> {
    let sql = if include_deleted {
        "SELECT id, date, start_time, end_time, title, category, type, completed, focus, sort_order, settled, source_device, created_at, updated_at, deleted
         FROM ls_schedule WHERE date = ?1 ORDER BY sort_order ASC, start_time ASC"
    } else {
        "SELECT id, date, start_time, end_time, title, category, type, completed, focus, sort_order, settled, source_device, created_at, updated_at, deleted
         FROM ls_schedule WHERE date = ?1 AND deleted = 0 ORDER BY sort_order ASC, start_time ASC"
    };
    let mut stmt = conn.prepare(sql).map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![date], map_schedule_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

/// 软删某天全部未软删的日程（batch_replace 时先软删再批量 upsert）。
pub fn soft_delete_schedules_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_schedule SET deleted = 1, updated_at = ?2 WHERE date = ?1 AND deleted = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// 沉淀：把某天全部日程标记 settled = 1（docs/09 §7.2 第 5 步）。
pub fn mark_schedules_settled_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_schedule SET settled = 1, updated_at = ?2 WHERE date = ?1 AND settled = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

// ============================ ls_quick_note ============================

pub fn upsert_quick_note(conn: &Connection, row: &QuickNoteRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_quick_note (id, date, content, source_device, settled, created_at, updated_at, deleted)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
         ON CONFLICT(id) DO UPDATE SET
            date = excluded.date,
            content = excluded.content,
            source_device = excluded.source_device,
            settled = excluded.settled,
            updated_at = excluded.updated_at,
            deleted = excluded.deleted",
        params![
            row.id,
            row.date,
            row.content,
            row.source_device,
            row.settled as i64,
            row.created_at,
            row.updated_at,
            row.deleted as i64,
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

fn map_quick_note_row(r: &rusqlite::Row) -> rusqlite::Result<QuickNoteRow> {
    Ok(QuickNoteRow {
        id: r.get(0)?,
        date: r.get(1)?,
        content: r.get(2)?,
        source_device: r.get(3)?,
        settled: r.get::<_, i64>(4)? != 0,
        created_at: r.get(5)?,
        updated_at: r.get(6)?,
        deleted: r.get::<_, i64>(7)? != 0,
    })
}

pub fn list_quick_notes_by_date(
    conn: &Connection,
    date: &str,
    include_deleted: bool,
) -> Result<Vec<QuickNoteRow>, String> {
    let sql = if include_deleted {
        "SELECT id, date, content, source_device, settled, created_at, updated_at, deleted
         FROM ls_quick_note WHERE date = ?1 ORDER BY created_at ASC"
    } else {
        "SELECT id, date, content, source_device, settled, created_at, updated_at, deleted
         FROM ls_quick_note WHERE date = ?1 AND deleted = 0 ORDER BY created_at ASC"
    };
    let mut stmt = conn.prepare(sql).map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![date], map_quick_note_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

pub fn soft_delete_quick_notes_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_quick_note SET deleted = 1, updated_at = ?2 WHERE date = ?1 AND deleted = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn mark_quick_notes_settled_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_quick_note SET settled = 1, updated_at = ?2 WHERE date = ?1 AND settled = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

// ============================ ls_review_answer ============================

pub fn upsert_review_answer(conn: &Connection, row: &ReviewAnswerRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_review_answer (id, date, question_id, title, content, settled, created_at, updated_at, deleted)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
         ON CONFLICT(id) DO UPDATE SET
            date = excluded.date,
            question_id = excluded.question_id,
            title = excluded.title,
            content = excluded.content,
            settled = excluded.settled,
            updated_at = excluded.updated_at,
            deleted = excluded.deleted",
        params![
            row.id,
            row.date,
            row.question_id,
            row.title,
            row.content,
            row.settled as i64,
            row.created_at,
            row.updated_at,
            row.deleted as i64,
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

fn map_review_answer_row(r: &rusqlite::Row) -> rusqlite::Result<ReviewAnswerRow> {
    Ok(ReviewAnswerRow {
        id: r.get(0)?,
        date: r.get(1)?,
        question_id: r.get(2)?,
        title: r.get(3)?,
        content: r.get(4)?,
        settled: r.get::<_, i64>(5)? != 0,
        created_at: r.get(6)?,
        updated_at: r.get(7)?,
        deleted: r.get::<_, i64>(8)? != 0,
    })
}

pub fn list_review_answers_by_date(
    conn: &Connection,
    date: &str,
    include_deleted: bool,
) -> Result<Vec<ReviewAnswerRow>, String> {
    let sql = if include_deleted {
        "SELECT id, date, question_id, title, content, settled, created_at, updated_at, deleted
         FROM ls_review_answer WHERE date = ?1 ORDER BY created_at ASC"
    } else {
        "SELECT id, date, question_id, title, content, settled, created_at, updated_at, deleted
         FROM ls_review_answer WHERE date = ?1 AND deleted = 0 ORDER BY created_at ASC"
    };
    let mut stmt = conn.prepare(sql).map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![date], map_review_answer_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

pub fn soft_delete_review_answers_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_review_answer SET deleted = 1, updated_at = ?2 WHERE date = ?1 AND deleted = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn mark_review_answers_settled_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_review_answer SET settled = 1, updated_at = ?2 WHERE date = ?1 AND settled = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

// ============================ ls_review_scheme ============================

pub fn upsert_review_scheme(conn: &Connection, row: &ReviewSchemeRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_review_scheme (id, name, source, is_default, is_active, payload, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
         ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            source = excluded.source,
            is_default = excluded.is_default,
            is_active = excluded.is_active,
            payload = excluded.payload,
            updated_at = excluded.updated_at",
        params![
            row.id,
            row.name,
            row.source,
            row.is_default as i64,
            row.is_active as i64,
            row.payload,
            row.updated_at,
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

fn map_review_scheme_row(r: &rusqlite::Row) -> rusqlite::Result<ReviewSchemeRow> {
    Ok(ReviewSchemeRow {
        id: r.get(0)?,
        name: r.get(1)?,
        source: r.get(2)?,
        is_default: r.get::<_, i64>(3)? != 0,
        is_active: r.get::<_, i64>(4)? != 0,
        payload: r.get(5)?,
        updated_at: r.get(6)?,
    })
}

pub fn list_review_schemes(conn: &Connection) -> Result<Vec<ReviewSchemeRow>, String> {
    let mut stmt = conn
        .prepare("SELECT id, name, source, is_default, is_active, payload, updated_at FROM ls_review_scheme ORDER BY is_default DESC, updated_at DESC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], map_review_scheme_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

// ============================ ls_daily_focus ============================

pub fn get_daily_focus(conn: &Connection, date: &str) -> Result<Option<DailyFocusRow>, String> {
    let row = conn
        .query_row(
            "SELECT date, content, settled, updated_at FROM ls_daily_focus WHERE date = ?1",
            params![date],
            |r| {
                Ok(DailyFocusRow {
                    date: r.get(0)?,
                    content: r.get(1)?,
                    settled: r.get::<_, i64>(2)? != 0,
                    updated_at: r.get(3)?,
                })
            },
        )
        .ok();
    Ok(row)
}

pub fn upsert_daily_focus(conn: &Connection, row: &DailyFocusRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_daily_focus (date, content, settled, updated_at)
         VALUES (?1, ?2, ?3, ?4)
         ON CONFLICT(date) DO UPDATE SET
            content = excluded.content,
            settled = excluded.settled,
            updated_at = excluded.updated_at",
        params![row.date, row.content, row.settled as i64, row.updated_at],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn mark_daily_focus_settled_by_date(conn: &Connection, date: &str, now: &str) -> Result<(), String> {
    conn.execute(
        "UPDATE ls_daily_focus SET settled = 1, updated_at = ?2 WHERE date = ?1 AND settled = 0",
        params![date, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

// ============================ ls_daily_settlement ============================

pub fn get_settlement(conn: &Connection, date: &str) -> Result<Option<SettlementRow>, String> {
    let row = conn
        .query_row(
            "SELECT date, md_content_hash, md_vault_path, settled_at, settled_by FROM ls_daily_settlement WHERE date = ?1",
            params![date],
            |r| {
                Ok(SettlementRow {
                    date: r.get(0)?,
                    md_content_hash: r.get(1)?,
                    md_vault_path: r.get(2)?,
                    settled_at: r.get(3)?,
                    settled_by: r.get(4)?,
                })
            },
        )
        .ok();
    Ok(row)
}

pub fn upsert_settlement(conn: &Connection, row: &SettlementRow) -> Result<(), String> {
    conn.execute(
        "INSERT INTO ls_daily_settlement (date, md_content_hash, md_vault_path, settled_at, settled_by)
         VALUES (?1, ?2, ?3, ?4, ?5)
         ON CONFLICT(date) DO UPDATE SET
            md_content_hash = excluded.md_content_hash,
            md_vault_path = excluded.md_vault_path,
            settled_at = excluded.settled_at,
            settled_by = excluded.settled_by",
        params![
            row.date,
            row.md_content_hash,
            row.md_vault_path,
            row.settled_at,
            row.settled_by,
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// 列出所有「过去日期且未沉淀」的日期（docs/09 §7.3 惰性补沉淀扫描）。
/// UNION 4 表 DISTINCT date WHERE date < today AND settled = 0（墓碑排除）。
pub fn list_unsettled_past_dates(conn: &Connection, today: &str) -> Result<Vec<String>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT DISTINCT date FROM ls_schedule WHERE date < ?1 AND settled = 0 AND deleted = 0
             UNION
             SELECT DISTINCT date FROM ls_quick_note WHERE date < ?1 AND settled = 0 AND deleted = 0
             UNION
             SELECT DISTINCT date FROM ls_review_answer WHERE date < ?1 AND settled = 0 AND deleted = 0
             UNION
             SELECT date FROM ls_daily_focus WHERE date < ?1 AND settled = 0
             ORDER BY date ASC",
        )
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![today], |r| r.get::<_, String>(0))
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

/// 列出某月有沉淀记录的日期（docs/09 §8 月历标记 settled 驱动）。
/// yearMonth = 'YYYY-MM'，LIKE 前缀匹配（'YYYY-MM%'）。
pub fn list_settled_dates_in_month(conn: &Connection, year_month: &str) -> Result<Vec<String>, String> {
    let prefix = format!("{}%", year_month);
    let mut stmt = conn
        .prepare("SELECT date FROM ls_daily_settlement WHERE date LIKE ?1 ORDER BY date ASC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![prefix], |r| r.get::<_, String>(0))
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

/// 列出全部未沉淀实体（settled=0 AND deleted=0），供 P4 跨设备 push（docs/09 §9.3）。
pub fn list_all_unsettled_schedules(conn: &Connection) -> Result<Vec<ScheduleRow>, String> {
    let mut stmt = conn
        .prepare("SELECT id, date, start_time, end_time, title, category, type, completed, focus, sort_order, settled, source_device, created_at, updated_at, deleted
         FROM ls_schedule WHERE settled = 0 AND deleted = 0 ORDER BY updated_at ASC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], map_schedule_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

pub fn list_all_unsettled_quick_notes(conn: &Connection) -> Result<Vec<QuickNoteRow>, String> {
    let mut stmt = conn
        .prepare("SELECT id, date, content, source_device, settled, created_at, updated_at, deleted
         FROM ls_quick_note WHERE settled = 0 AND deleted = 0 ORDER BY updated_at ASC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], map_quick_note_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

pub fn list_all_unsettled_review_answers(conn: &Connection) -> Result<Vec<ReviewAnswerRow>, String> {
    let mut stmt = conn
        .prepare("SELECT id, date, question_id, title, content, settled, created_at, updated_at, deleted
         FROM ls_review_answer WHERE settled = 0 AND deleted = 0 ORDER BY updated_at ASC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], map_review_answer_row)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

pub fn list_all_unsettled_daily_focus(conn: &Connection) -> Result<Vec<DailyFocusRow>, String> {
    let mut stmt = conn
        .prepare("SELECT date, content, settled, updated_at
         FROM ls_daily_focus WHERE settled = 0 ORDER BY updated_at ASC")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], |r| {
            Ok(DailyFocusRow {
                date: r.get(0)?,
                content: r.get(1)?,
                settled: r.get::<_, i64>(2)? != 0,
                updated_at: r.get(3)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}
