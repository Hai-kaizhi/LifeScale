//! Vault 文件系统操作：扫描(含 hash)、读、原子写、删。所有相对路径都做安全收敛（仅 Normal 段、不逃出 root）。
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::path::{Component, Path, PathBuf};

/// 一份本地文件条目（相对路径 + 大小 + mtime + 内容 hash）。
#[derive(Debug, Serialize)]
pub struct VaultFileEntry {
    pub path: String,
    pub size: i64,
    pub mtime: i64,
    pub hash: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VaultTreeEntry {
    pub path: String,
    pub name: String,
    pub kind: String,
    pub parent_path: Option<String>,
    pub size: Option<i64>,
    pub ctime: Option<i64>,
    pub mtime: Option<i64>,
    pub hash: Option<String>,
}

/// 递归扫描 vault 下的 .md 文件（跳过 .lifescale/），计算每份内容的 SHA-256。
pub fn list_files(root: &Path) -> Result<Vec<VaultFileEntry>, String> {
    let canon = root.canonicalize().map_err(|e| format!("根目录无效: {e}"))?;
    let mut out = Vec::new();
    for entry in walkdir::WalkDir::new(&canon)
        .into_iter()
        .filter_entry(|e| !is_lifescale_hidden(e.path(), &canon))
    {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        if !entry.file_type().is_file() {
            continue;
        }
        let abs = entry.path();
        let rel = match rel_path(&canon, abs) {
            Some(r) => r,
            None => continue,
        };
        if !rel.ends_with(".md") {
            continue; // 本阶段只同步 Markdown 文档层；附件后续扩展
        }
        let meta = match std::fs::metadata(abs) {
            Ok(m) => m,
            Err(_) => continue,
        };
        let bytes = match std::fs::read(abs) {
            Ok(b) => b,
            Err(_) => continue,
        };
        let mtime = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);
        out.push(VaultFileEntry {
            path: rel,
            size: meta.len() as i64,
            mtime,
            hash: hex_hash(&bytes),
        });
    }
    out.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(out)
}

pub fn list_tree(root: &Path) -> Result<Vec<VaultTreeEntry>, String> {
    let canon = root.canonicalize().map_err(|e| format!("根目录无效: {e}"))?;
    let mut out = Vec::new();
    let mut seen_dirs = HashSet::new();

    for entry in walkdir::WalkDir::new(&canon)
        .into_iter()
        .filter_entry(|e| !is_lifescale_hidden(e.path(), &canon))
    {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        let abs = entry.path();
        if abs == canon {
            continue;
        }
        let rel = match rel_path(&canon, abs) {
            Some(r) => r,
            None => continue,
        };

        if entry.file_type().is_dir() {
            if seen_dirs.insert(rel.clone()) {
                let (ctime, mtime) = match std::fs::metadata(abs) {
                    Ok(meta) => {
                        let mtime = metadata_modified_millis(&meta).unwrap_or(0);
                        (Some(metadata_created_millis(&meta, mtime)), Some(mtime))
                    }
                    Err(_) => (None, None),
                };
                out.push(VaultTreeEntry {
                    name: leaf_name(&rel),
                    parent_path: parent_rel_path(&rel),
                    path: rel,
                    kind: "folder".into(),
                    size: None,
                    ctime,
                    mtime,
                    hash: None,
                });
            }
            continue;
        }

        if !entry.file_type().is_file() || !rel.ends_with(".md") {
            continue;
        }

        let meta = match std::fs::metadata(abs) {
            Ok(m) => m,
            Err(_) => continue,
        };
        let bytes = match std::fs::read(abs) {
            Ok(b) => b,
            Err(_) => continue,
        };
        let mtime = metadata_modified_millis(&meta).unwrap_or(0);
        let ctime = metadata_created_millis(&meta, mtime);
        out.push(VaultTreeEntry {
            name: leaf_name(&rel),
            parent_path: parent_rel_path(&rel),
            path: rel,
            kind: "file".into(),
            size: Some(meta.len() as i64),
            ctime: Some(ctime),
            mtime: Some(mtime),
            hash: Some(hex_hash(&bytes)),
        });
    }

    out.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(out)
}

/// 读一份文件为 UTF-8 文本。
pub fn read_file(root: &Path, rel: &str) -> Result<String, String> {
    let target = safe_target(root, rel)?;
    std::fs::read_to_string(&target).map_err(|e| format!("读取失败 {rel}: {e}"))
}

/// 原子写：先写同目录临时文件，再 rename 覆盖（防半写 / 崩溃损坏）。
pub fn atomic_write(root: &Path, rel: &str, content: &str) -> Result<(), String> {
    let target = safe_target(root, rel)?;
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("创建目录失败: {e}"))?;
    }
    let tmp = target.with_extension("md.tmp"); // 同目录临时文件，保证同卷 rename 原子
    std::fs::write(&tmp, content.as_bytes()).map_err(|e| format!("写临时文件失败: {e}"))?;
    std::fs::rename(&tmp, &target).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename 失败: {e}")
    })?;
    Ok(())
}

/// 删除文件（不存在视为成功）。
pub fn delete_file(root: &Path, rel: &str) -> Result<bool, String> {
    let target = safe_target(root, rel)?;
    match std::fs::remove_file(&target) {
        Ok(_) => Ok(true),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(true),
        Err(e) => Err(format!("删除失败 {rel}: {e}")),
    }
}

pub fn rename_file(root: &Path, from_rel: &str, to_rel: &str) -> Result<(), String> {
    if !from_rel.ends_with(".md") || !to_rel.ends_with(".md") {
        return Err("仅允许重命名 .md 文件".into());
    }
    let from = safe_target(root, from_rel)?;
    let to = safe_target(root, to_rel)?;
    if !from.exists() {
        return Err(format!("文件不存在: {from_rel}"));
    }
    if !from.is_file() {
        return Err(format!("不是文件: {from_rel}"));
    }
    if to.exists() {
        return Err(format!("目标文件已存在: {to_rel}"));
    }
    if let Some(parent) = to.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("创建目录失败: {e}"))?;
    }
    std::fs::rename(&from, &to).map_err(|e| format!("重命名文件失败 {from_rel} -> {to_rel}: {e}"))
}

pub fn create_dir(root: &Path, rel: &str) -> Result<(), String> {
    let target = safe_target(root, rel)?;
    std::fs::create_dir_all(&target).map_err(|e| format!("创建目录失败 {rel}: {e}"))
}

pub fn rename_dir(root: &Path, from_rel: &str, to_rel: &str) -> Result<(), String> {
    let from = safe_target(root, from_rel)?;
    let to = safe_target(root, to_rel)?;
    if !from.exists() {
        return Err(format!("目录不存在: {from_rel}"));
    }
    if to.exists() {
        return Err(format!("目标目录已存在: {to_rel}"));
    }
    if let Some(parent) = to.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("创建目录失败: {e}"))?;
    }
    std::fs::rename(&from, &to).map_err(|e| format!("重命名目录失败 {from_rel} -> {to_rel}: {e}"))
}

pub fn delete_dir(root: &Path, rel: &str, recursive: bool) -> Result<(), String> {
    let target = safe_target(root, rel)?;
    if !target.exists() {
        return Ok(());
    }
    if recursive {
        std::fs::remove_dir_all(&target).map_err(|e| format!("删除目录失败 {rel}: {e}"))
    } else {
        std::fs::remove_dir(&target).map_err(|e| format!("删除目录失败 {rel}: {e}"))
    }
}

/// 读一份文件为 base64 字符串（字节级，供附件等二进制跨 Tauri invoke 桥传输）。
pub fn read_file_bytes(root: &Path, rel: &str) -> Result<Option<String>, String> {
    let target = safe_target(root, rel)?;
    if !target.exists() {
        return Ok(None);
    }
    let bytes = std::fs::read(&target).map_err(|e| format!("读取失败 {rel}: {e}"))?;
    Ok(Some(BASE64.encode(&bytes)))
}

/// 原子写字节（base64 解码后写）：先写同目录临时文件，再 rename 覆盖。供附件缓存等二进制写。
pub fn atomic_write_bytes(root: &Path, rel: &str, b64: &str) -> Result<(), String> {
    let target = safe_target(root, rel)?;
    let bytes = BASE64.decode(b64.as_bytes()).map_err(|e| format!("base64 解码失败 {rel}: {e}"))?;
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("创建目录失败: {e}"))?;
    }
    let tmp = target.with_extension("tmp");
    std::fs::write(&tmp, &bytes).map_err(|e| format!("写临时文件失败: {e}"))?;
    std::fs::rename(&tmp, &target).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename 失败: {e}")
    })?;
    Ok(())
}

/// 文件是否存在（供前端探本地附件缓存）。
pub fn exists_file(root: &Path, rel: &str) -> Result<bool, String> {
    let target = safe_target(root, rel)?;
    Ok(target.exists())
}

/// 收敛相对路径：仅保留 Normal 段，并确保结果仍在 root 下（防 .. 与绝对路径逃逸）。
fn safe_target(root: &Path, rel: &str) -> Result<PathBuf, String> {
    if rel.trim().is_empty() {
        return Err("相对路径不能为空".into());
    }
    let canon = root.canonicalize().map_err(|e| format!("根目录无效: {e}"))?;
    let mut safe = PathBuf::new();
    for c in Path::new(rel).components() {
        match c {
            Component::Normal(s) => safe.push(s),
            _ => return Err(format!("相对路径包含不安全片段: {rel}")),
        }
    }
    let target = canon.join(&safe);
    if !target.starts_with(&canon) {
        return Err(format!("路径逃出 vault 根: {rel}"));
    }
    Ok(target)
}

/// 计算相对 root 的 POSIX 风格相对路径。
fn rel_path(root: &Path, abs: &Path) -> Option<String> {
    let rel = abs.strip_prefix(root).ok()?;
    let mut s = String::new();
    for c in rel.components() {
        if let Component::Normal(seg) = c {
            if !s.is_empty() {
                s.push('/');
            }
            s.push_str(&seg.to_string_lossy());
        }
    }
    if s.is_empty() {
        None
    } else {
        Some(s)
    }
}

fn parent_rel_path(rel: &str) -> Option<String> {
    let path = Path::new(rel);
    let parent = path.parent()?;
    let raw = parent.to_string_lossy().replace('\\', "/");
    if raw.is_empty() {
        None
    } else {
        Some(raw)
    }
}

fn leaf_name(rel: &str) -> String {
    Path::new(rel)
        .file_name()
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|| rel.to_string())
}

fn is_lifescale_hidden(p: &Path, root: &Path) -> bool {
    let rel = match p.strip_prefix(root) {
        Ok(r) => r,
        Err(_) => return false,
    };
    rel.components().any(|c| match c {
        Component::Normal(seg) => seg == std::ffi::OsStr::new(".lifescale"),
        _ => false,
    })
}

fn system_time_millis(time: std::time::SystemTime) -> Option<i64> {
    time.duration_since(std::time::UNIX_EPOCH)
        .ok()
        .map(|d| d.as_millis() as i64)
}

fn metadata_modified_millis(meta: &std::fs::Metadata) -> Option<i64> {
    meta.modified().ok().and_then(system_time_millis)
}

fn metadata_created_millis(meta: &std::fs::Metadata, fallback: i64) -> i64 {
    meta.created()
        .ok()
        .and_then(system_time_millis)
        .unwrap_or(fallback)
}

fn hex_hash(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    let digest = hasher.finalize();
    let mut out = String::with_capacity(64);
    for b in digest {
        out.push_str(&format!("{:02x}", b));
    }
    out
}
