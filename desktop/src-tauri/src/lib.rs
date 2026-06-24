mod fs_ops;
mod lifescale_db;
mod sync_db;
mod watcher;

use notify::RecommendedWatcher;
use serde::Serialize;
use std::path::{Component, Path, PathBuf};
use std::sync::Mutex;
use tauri::{AppHandle, Manager, State};

/// 应用级状态：当前 vault 监听器（drop 即停止）。
struct AppState {
    watcher: Mutex<Option<RecommendedWatcher>>,
}

#[tauri::command]
fn ensure_default_vault_root(app: AppHandle) -> Result<String, String> {
    let root = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("获取应用数据目录失败: {e}"))?
        .join("Vault");
    std::fs::create_dir_all(&root).map_err(|e| format!("创建默认 Vault 目录失败: {e}"))?;
    Ok(root.to_string_lossy().into_owned())
}

// ============================ 既有：每日 Markdown 写盘（兼容旧流程） ============================

#[tauri::command]
fn write_daily_markdown_file(root_path: String, relative_path: String, content: String) -> Result<(), String> {
    let root = PathBuf::from(root_path.trim());
    if root.as_os_str().is_empty() {
        return Err("Markdown 保存根目录不能为空".into());
    }
    if !root.is_absolute() {
        return Err("Markdown 保存根目录必须是绝对路径".into());
    }

    let relative = Path::new(relative_path.trim());
    if relative.as_os_str().is_empty() {
        return Err("Markdown 相对路径不能为空".into());
    }
    match relative.extension().and_then(|value| value.to_str()) {
        Some(ext) if ext.eq_ignore_ascii_case("md") => {}
        _ => return Err("仅允许写入 .md 文件".into()),
    }

    let mut safe_relative = PathBuf::new();
    for component in relative.components() {
        match component {
            Component::Normal(value) => safe_relative.push(value),
            _ => return Err("Markdown 相对路径包含不安全片段".into()),
        }
    }

    let target = root.join(safe_relative);
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent).map_err(|err| format!("创建目录失败：{err}"))?;
    }
    std::fs::write(&target, content).map_err(|err| format!("写入 Markdown 文件失败：{err}"))?;
    Ok(())
}

// ============================ Vault 文件操作 ============================

#[tauri::command]
fn list_vault_files(root: String) -> Result<Vec<fs_ops::VaultFileEntry>, String> {
    fs_ops::list_files(&PathBuf::from(root))
}

#[tauri::command]
fn list_vault_tree(root: String) -> Result<Vec<fs_ops::VaultTreeEntry>, String> {
    fs_ops::list_tree(&PathBuf::from(root))
}

#[tauri::command]
fn read_vault_file(root: String, path: String) -> Result<String, String> {
    fs_ops::read_file(&PathBuf::from(root), &path)
}

#[tauri::command]
fn atomic_write_file(root: String, path: String, content: String) -> Result<(), String> {
    fs_ops::atomic_write(&PathBuf::from(root), &path, &content)
}

#[tauri::command]
fn delete_vault_file(root: String, path: String) -> Result<bool, String> {
    fs_ops::delete_file(&PathBuf::from(root), &path)
}

#[tauri::command]
fn rename_vault_file(root: String, from_path: String, to_path: String) -> Result<(), String> {
    fs_ops::rename_file(&PathBuf::from(root), &from_path, &to_path)
}

#[tauri::command]
fn create_vault_directory(root: String, path: String) -> Result<(), String> {
    fs_ops::create_dir(&PathBuf::from(root), &path)
}

#[tauri::command]
fn rename_vault_directory(root: String, from_path: String, to_path: String) -> Result<(), String> {
    fs_ops::rename_dir(&PathBuf::from(root), &from_path, &to_path)
}

#[tauri::command]
fn delete_vault_directory(root: String, path: String, recursive: bool) -> Result<(), String> {
    fs_ops::delete_dir(&PathBuf::from(root), &path, recursive)
}

#[tauri::command]
fn read_vault_file_bytes(root: String, path: String) -> Result<Option<String>, String> {
    fs_ops::read_file_bytes(&PathBuf::from(root), &path)
}

#[tauri::command]
fn atomic_write_bytes(root: String, path: String, b64: String) -> Result<(), String> {
    fs_ops::atomic_write_bytes(&PathBuf::from(root), &path, &b64)
}

#[tauri::command]
fn exists_vault_file(root: String, path: String) -> Result<bool, String> {
    fs_ops::exists_file(&PathBuf::from(root), &path)
}

// ============================ Vault 文件夹监听 ============================

#[tauri::command]
fn start_vault_watch(app: AppHandle, state: State<'_, AppState>, root: String) -> Result<(), String> {
    let mut slot = state.watcher.lock().map_err(|e| e.to_string())?;
    *slot = None; // 先停掉旧监听器
    watcher::start(app, PathBuf::from(root), &mut slot)
}

#[tauri::command]
fn stop_vault_watch(state: State<'_, AppState>) -> Result<(), String> {
    let mut slot = state.watcher.lock().map_err(|e| e.to_string())?;
    *slot = None;
    Ok(())
}

// ============================ 本地同步状态索引 ============================

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncStateOut {
    vault_path: String,
    local_hash: Option<String>,
    synced_hash: Option<String>,
    status: String,
    base_version: Option<i64>,
    local_mtime: Option<i64>,
}

impl From<sync_db::SyncStateRow> for SyncStateOut {
    fn from(r: sync_db::SyncStateRow) -> Self {
        Self {
            vault_path: r.vault_path,
            local_hash: r.local_hash,
            synced_hash: r.synced_hash,
            status: r.status,
            base_version: r.base_version,
            local_mtime: r.local_mtime,
        }
    }
}

#[tauri::command]
fn sync_state_upsert(
    root: String,
    vault_path: String,
    local_hash: Option<String>,
    status: String,
    base_version: Option<i64>,
    local_mtime: Option<i64>,
) -> Result<(), String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::upsert(&conn, &vault_path, local_hash.as_deref(), &status, base_version, local_mtime)
}

#[tauri::command]
fn sync_state_get(root: String, vault_path: String) -> Result<Option<SyncStateOut>, String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    Ok(sync_db::get(&conn, &vault_path)?.map(SyncStateOut::from))
}

#[tauri::command]
fn sync_state_mark_synced(root: String, vault_path: String, synced_hash: String) -> Result<(), String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::mark_synced(&conn, &vault_path, &synced_hash)
}

#[tauri::command]
fn sync_state_list(root: String, status: String) -> Result<Vec<SyncStateOut>, String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    Ok(sync_db::list_by_status(&conn, &status)?.into_iter().map(SyncStateOut::from).collect())
}

#[tauri::command]
fn sync_state_remove(root: String, vault_path: String) -> Result<(), String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::remove(&conn, &vault_path)
}

#[tauri::command]
fn sync_meta_get(root: String, key: String) -> Result<Option<String>, String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::meta_get(&conn, &key)
}

#[tauri::command]
fn sync_meta_set(root: String, key: String, value: String) -> Result<(), String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::meta_set(&conn, &key, &value)
}

#[tauri::command]
fn sync_last_cursor(root: String) -> Result<Option<String>, String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::last_pulled_cursor(&conn)
}

#[tauri::command]
fn sync_set_cursor(root: String, cursor: String) -> Result<(), String> {
    let conn = sync_db::open(&PathBuf::from(root))?;
    sync_db::set_last_pulled_cursor(&conn, &cursor)
}

// ============================ 业务真相源库（docs/09 SQL-first）============================

#[tauri::command]
fn ls_upsert_schedule(root: String, schedule: lifescale_db::ScheduleRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_schedule(&conn, &schedule)
}

#[tauri::command]
fn ls_list_schedules_by_date(
    root: String,
    date: String,
    include_deleted: bool,
) -> Result<Vec<lifescale_db::ScheduleRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_schedules_by_date(&conn, &date, include_deleted)
}

#[tauri::command]
fn ls_soft_delete_schedules_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::soft_delete_schedules_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_upsert_quick_note(root: String, quick_note: lifescale_db::QuickNoteRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_quick_note(&conn, &quick_note)
}

#[tauri::command]
fn ls_list_quick_notes_by_date(
    root: String,
    date: String,
    include_deleted: bool,
) -> Result<Vec<lifescale_db::QuickNoteRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_quick_notes_by_date(&conn, &date, include_deleted)
}

#[tauri::command]
fn ls_soft_delete_quick_notes_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::soft_delete_quick_notes_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_upsert_review_answer(root: String, answer: lifescale_db::ReviewAnswerRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_review_answer(&conn, &answer)
}

#[tauri::command]
fn ls_list_review_answers_by_date(
    root: String,
    date: String,
    include_deleted: bool,
) -> Result<Vec<lifescale_db::ReviewAnswerRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_review_answers_by_date(&conn, &date, include_deleted)
}

#[tauri::command]
fn ls_soft_delete_review_answers_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::soft_delete_review_answers_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_get_daily_focus(root: String, date: String) -> Result<Option<lifescale_db::DailyFocusRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::get_daily_focus(&conn, &date)
}

#[tauri::command]
fn ls_upsert_daily_focus(root: String, focus: lifescale_db::DailyFocusRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_daily_focus(&conn, &focus)
}

#[tauri::command]
fn ls_upsert_review_scheme(root: String, scheme: lifescale_db::ReviewSchemeRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_review_scheme(&conn, &scheme)
}

#[tauri::command]
fn ls_list_review_schemes(root: String) -> Result<Vec<lifescale_db::ReviewSchemeRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_review_schemes(&conn)
}

// ---- 沉淀标记（docs/09 §7.2 第 5 步，P2 沉淀流程用，P1 先提供命令）----

#[tauri::command]
fn ls_mark_schedules_settled_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::mark_schedules_settled_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_mark_quick_notes_settled_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::mark_quick_notes_settled_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_mark_review_answers_settled_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::mark_review_answers_settled_by_date(&conn, &date, &now)
}

#[tauri::command]
fn ls_mark_daily_focus_settled_by_date(root: String, date: String, now: String) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::mark_daily_focus_settled_by_date(&conn, &date, &now)
}

// ---- 沉淀记录（docs/09 §6.1.3 对账核心，P2 用，P1 先提供命令）----

#[tauri::command]
fn ls_get_settlement(root: String, date: String) -> Result<Option<lifescale_db::SettlementRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::get_settlement(&conn, &date)
}

#[tauri::command]
fn ls_upsert_settlement(root: String, settlement: lifescale_db::SettlementRow) -> Result<(), String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::upsert_settlement(&conn, &settlement)
}

#[tauri::command]
fn ls_list_unsettled_past_dates(root: String, today: String) -> Result<Vec<String>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_unsettled_past_dates(&conn, &today)
}

#[tauri::command]
fn ls_list_settled_dates_in_month(root: String, year_month: String) -> Result<Vec<String>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_settled_dates_in_month(&conn, &year_month)
}

#[tauri::command]
fn ls_list_all_unsettled_schedules(root: String) -> Result<Vec<lifescale_db::ScheduleRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_all_unsettled_schedules(&conn)
}

#[tauri::command]
fn ls_list_all_unsettled_quick_notes(root: String) -> Result<Vec<lifescale_db::QuickNoteRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_all_unsettled_quick_notes(&conn)
}

#[tauri::command]
fn ls_list_all_unsettled_review_answers(root: String) -> Result<Vec<lifescale_db::ReviewAnswerRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_all_unsettled_review_answers(&conn)
}

#[tauri::command]
fn ls_list_all_unsettled_daily_focus(root: String) -> Result<Vec<lifescale_db::DailyFocusRow>, String> {
    let conn = lifescale_db::open(&PathBuf::from(root))?;
    lifescale_db::list_all_unsettled_daily_focus(&conn)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState {
            watcher: Mutex::new(None),
        })
        .invoke_handler(tauri::generate_handler![
            write_daily_markdown_file,
            ensure_default_vault_root,
            list_vault_files,
            list_vault_tree,
            read_vault_file,
            atomic_write_file,
            delete_vault_file,
            rename_vault_file,
            create_vault_directory,
            rename_vault_directory,
            delete_vault_directory,
            read_vault_file_bytes,
            atomic_write_bytes,
            exists_vault_file,
            start_vault_watch,
            stop_vault_watch,
            sync_state_upsert,
            sync_state_get,
            sync_state_mark_synced,
            sync_state_list,
            sync_state_remove,
            sync_meta_get,
            sync_meta_set,
            sync_last_cursor,
            sync_set_cursor,
            ls_upsert_schedule,
            ls_list_schedules_by_date,
            ls_soft_delete_schedules_by_date,
            ls_upsert_quick_note,
            ls_list_quick_notes_by_date,
            ls_soft_delete_quick_notes_by_date,
            ls_upsert_review_answer,
            ls_list_review_answers_by_date,
            ls_soft_delete_review_answers_by_date,
            ls_get_daily_focus,
            ls_upsert_daily_focus,
            ls_upsert_review_scheme,
            ls_list_review_schemes,
            ls_mark_schedules_settled_by_date,
            ls_mark_quick_notes_settled_by_date,
            ls_mark_review_answers_settled_by_date,
            ls_mark_daily_focus_settled_by_date,
            ls_get_settlement,
            ls_upsert_settlement,
            ls_list_unsettled_past_dates,
            ls_list_settled_dates_in_month,
            ls_list_all_unsettled_schedules,
            ls_list_all_unsettled_quick_notes,
            ls_list_all_unsettled_review_answers,
            ls_list_all_unsettled_daily_focus,
        ])
        .run(tauri::generate_context!())
        .expect("运行 Tauri 应用时发生错误");
}
