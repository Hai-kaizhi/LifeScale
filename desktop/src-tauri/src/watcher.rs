//! Vault 文件夹监听：notify 6 递归监听，静默期(300ms)去抖后向前端 emit "vault-change"。
//! 自动忽略 .lifescale/ 隐藏目录；watcher 存于 AppState，drop 即停止（后台线程随之退出）。
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use serde::Serialize;
use std::collections::HashSet;
use std::path::{Component, Path, PathBuf};
use std::sync::mpsc;
use std::time::Duration;
use tauri::{AppHandle, Emitter};

/// 前端收到的事件载荷：一批相对路径发生了变化。
#[derive(Clone, Serialize)]
pub struct VaultChangePayload {
    pub paths: Vec<String>,
}

/// 启动监听：把 watcher 存入 slot（由调用方持有生命周期）。
pub fn start(app: AppHandle, root: PathBuf, slot: &mut Option<RecommendedWatcher>) -> Result<(), String> {
    let canon = root.canonicalize().map_err(|e| format!("根目录无效: {e}"))?;
    let (tx, rx) = mpsc::channel::<notify::Result<notify::Event>>();
    let mut watcher = RecommendedWatcher::new(tx, notify::Config::default())
        .map_err(|e| format!("创建监听器失败: {e}"))?;
    watcher
        .watch(&canon, RecursiveMode::Recursive)
        .map_err(|e| format!("监听失败: {e}"))?;

    *slot = Some(watcher);

    let app_for_thread = app.clone();
    let root_for_thread = canon.clone();
    std::thread::spawn(move || {
        let quiet = Duration::from_millis(300);
        let mut pending: HashSet<String> = HashSet::new();
        loop {
            match rx.recv_timeout(quiet) {
                Ok(Ok(ev)) => {
                    for p in ev.paths {
                        if let Some(rel) = rel_from(&root_for_thread, &p) {
                            pending.insert(rel);
                        }
                    }
                }
                Ok(Err(_)) => { /* 单次事件错误忽略，继续监听 */ }
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    if !pending.is_empty() {
                        let paths: Vec<String> = pending.drain().collect();
                        let _ = app_for_thread.emit("vault-change", VaultChangePayload { paths });
                    }
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            }
        }
    });
    Ok(())
}

/// 计算相对 root 的 POSIX 风格路径；落在 .lifescale/ 或 attachments/ 下则返回 None（被忽略）。
/// attachments/ 是内容寻址附件的本地缓存，经独立通道同步，忽略以防 vault-change 自激回环。
fn rel_from(root: &Path, abs: &Path) -> Option<String> {
    let rel = abs.strip_prefix(root).ok()?;
    let mut segs: Vec<String> = Vec::new();
    for c in rel.components() {
        match c {
            Component::Normal(s) => segs.push(s.to_string_lossy().into_owned()),
            _ => return None,
        }
    }
    if segs.is_empty() {
        return None;
    }
    if segs.iter().any(|s| s == ".lifescale") {
        return None;
    }
    if segs.first().map(|s| s == "attachments").unwrap_or(false) {
        return None;
    }
    Some(segs.join("/"))
}
