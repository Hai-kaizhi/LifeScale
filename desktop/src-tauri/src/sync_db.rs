//! Vault 本地同步状态索引：`<vault>/.lifescale/sync.db`（SQLite，仿 Obsidian 的 .obsidian/）。
//! 维护每个 vault_path 的 local_hash / synced_hash / status(clean/dirty/pending/conflict)，
//! 以及 sync_meta（如 last_pulled_cursor）。.md 文件本身保持纯净，元数据只落这里。
use rusqlite::{params, Connection};
use serde::Serialize;
use std::path::{Path, PathBuf};

const META_LAST_CURSOR: &str = "last_pulled_cursor";

/// 单条同步状态。
#[derive(Debug, Clone, Serialize)]
pub struct SyncStateRow {
    pub vault_path: String,
    pub local_hash: Option<String>,
    pub synced_hash: Option<String>,
    pub status: String,
    pub base_version: Option<i64>,
    pub local_mtime: Option<i64>,
}

/// 打开（必要时创建）<root>/.lifescale/sync.db，建表，开 WAL + busy_timeout。
pub fn open(root: &Path) -> Result<Connection, String> {
    let dir: PathBuf = root.join(".lifescale");
    std::fs::create_dir_all(&dir).map_err(|e| format!("创建 .lifescale 失败: {e}"))?;
    let db_path = dir.join("sync.db");
    let conn = Connection::open(&db_path).map_err(|e| format!("打开 sync.db 失败: {e}"))?;
    conn.pragma_update(None, "journal_mode", "WAL")
        .map_err(|e| e.to_string())?;
    conn.pragma_update(None, "busy_timeout", 5000)
        .map_err(|e| e.to_string())?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS sync_state (
            vault_path    TEXT PRIMARY KEY,
            local_hash    TEXT,
            synced_hash   TEXT,
            status        TEXT NOT NULL DEFAULT 'clean',
            base_version  INTEGER,
            local_mtime   INTEGER,
            updated_at    INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS sync_meta (
            key   TEXT PRIMARY KEY,
            value TEXT
        );",
    )
    .map_err(|e| e.to_string())?;
    Ok(conn)
}

/// 插入或更新一条状态（本地有改动时调用，status 一般为 dirty/pending）。
pub fn upsert(
    conn: &Connection,
    vault_path: &str,
    local_hash: Option<&str>,
    status: &str,
    base_version: Option<i64>,
    local_mtime: Option<i64>,
) -> Result<(), String> {
    let now = now_millis();
    let synced_hash = if status == "clean" { local_hash } else { None };
    conn.execute(
        "INSERT INTO sync_state (vault_path, local_hash, synced_hash, status, base_version, local_mtime, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
         ON CONFLICT(vault_path) DO UPDATE SET
            local_hash = excluded.local_hash,
            status = excluded.status,
            base_version = excluded.base_version,
            local_mtime = excluded.local_mtime,
            updated_at = excluded.updated_at",
        params![vault_path, local_hash, synced_hash, status, base_version, local_mtime, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// 推送/拉取成功后标记已同步：synced_hash = local_hash，status = clean。
pub fn mark_synced(conn: &Connection, vault_path: &str, synced_hash: &str) -> Result<(), String> {
    let now = now_millis();
    conn.execute(
        "UPDATE sync_state SET synced_hash = ?2, status = 'clean', updated_at = ?3 WHERE vault_path = ?1",
        params![vault_path, synced_hash, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn get(conn: &Connection, vault_path: &str) -> Result<Option<SyncStateRow>, String> {
    let mut stmt = conn
        .prepare("SELECT vault_path, local_hash, synced_hash, status, base_version, local_mtime FROM sync_state WHERE vault_path = ?1")
        .map_err(|e| e.to_string())?;
    let row = stmt
        .query_row(params![vault_path], |r| {
            Ok(SyncStateRow {
                vault_path: r.get(0)?,
                local_hash: r.get(1)?,
                synced_hash: r.get(2)?,
                status: r.get(3)?,
                base_version: r.get(4)?,
                local_mtime: r.get(5)?,
            })
        })
        .ok();
    Ok(row)
}

/// 列出某状态的所有行（dirty/pending/conflict）。
pub fn list_by_status(conn: &Connection, status: &str) -> Result<Vec<SyncStateRow>, String> {
    let mut stmt = conn
        .prepare("SELECT vault_path, local_hash, synced_hash, status, base_version, local_mtime FROM sync_state WHERE status = ?1")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![status], |r| {
            Ok(SyncStateRow {
                vault_path: r.get(0)?,
                local_hash: r.get(1)?,
                synced_hash: r.get(2)?,
                status: r.get(3)?,
                base_version: r.get(4)?,
                local_mtime: r.get(5)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    Ok(rows)
}

/// 删除本地已不存在的文件状态（对账时清理）。
pub fn remove(conn: &Connection, vault_path: &str) -> Result<(), String> {
    conn.execute("DELETE FROM sync_state WHERE vault_path = ?1", params![vault_path])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn meta_get(conn: &Connection, key: &str) -> Result<Option<String>, String> {
    let v = conn
        .query_row("SELECT value FROM sync_meta WHERE key = ?1", params![key], |r| r.get::<_, String>(0))
        .ok();
    Ok(v)
}

pub fn meta_set(conn: &Connection, key: &str, value: &str) -> Result<(), String> {
    conn.execute(
        "INSERT INTO sync_meta (key, value) VALUES (?1, ?2) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        params![key, value],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn last_pulled_cursor(conn: &Connection) -> Result<Option<String>, String> {
    meta_get(conn, META_LAST_CURSOR)
}

pub fn set_last_pulled_cursor(conn: &Connection, cursor: &str) -> Result<(), String> {
    meta_set(conn, META_LAST_CURSOR, cursor)
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
