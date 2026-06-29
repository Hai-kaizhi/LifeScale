import type { VaultChangePayload, VaultFileEntry, VaultTreeEntry } from '../../shared/types/vault';

type RawVaultTreeEntry = Omit<VaultTreeEntry, 'parentPath'> & {
  parentPath?: string | null;
  parent_path?: string | null;
};

/**
 * Vault 本地文件桥：封装 Tauri 命令（list/read/atomic-write/delete/watch）。
 * 非 Tauri 环境（浏览器/mock 开发）下用内存 vault 兜底，保证同步引擎逻辑可联调。
 */
export function isTauriRuntime(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

export async function tauriInvoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  const { invoke } = await import('@tauri-apps/api/core');
  return invoke<T>(cmd, args);
}

// ---- 内存兜底（仅非 Tauri）----
const memoryVault = new Map<string, string>();
const memoryVaultBytes = new Map<string, Uint8Array>();
const memoryVaultDirectories = new Set<string>();

function normalizeVaultPath(path: string): string {
  return path.replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
}

function parentDirectoryPath(path: string): string | null {
  const normalized = normalizeVaultPath(path);
  if (!normalized) {
    return null;
  }
  const index = normalized.lastIndexOf('/');
  return index === -1 ? null : normalized.slice(0, index);
}

function basename(path: string): string {
  const normalized = normalizeVaultPath(path);
  const index = normalized.lastIndexOf('/');
  return index === -1 ? normalized : normalized.slice(index + 1);
}

function normalizeVaultTreeEntries(entries: RawVaultTreeEntry[]): VaultTreeEntry[] {
  return entries.map((entry) => {
    const path = normalizeVaultPath(entry.path);
    const rawParentPath = entry.parentPath ?? entry.parent_path ?? parentDirectoryPath(path);
    const parentPath = rawParentPath ? normalizeVaultPath(rawParentPath) : null;
    return {
      path,
      name: entry.name || basename(path),
      kind: entry.kind,
      parentPath,
      size: entry.size,
      ctime: entry.ctime,
      mtime: entry.mtime,
      hash: entry.hash,
    };
  });
}

function ensureMemoryDirectory(path: string | null): void {
  let current = path ? normalizeVaultPath(path) : '';
  while (current) {
    memoryVaultDirectories.add(current);
    current = parentDirectoryPath(current) ?? '';
  }
}

/** Uint8Array → base64（分块，避免大数组展开栈溢出）。 */
function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/** base64 → Uint8Array。 */
function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function sha256HexBytes(bytes: Uint8Array): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export async function sha256Hex(text: string): Promise<string> {
  return sha256HexBytes(new TextEncoder().encode(text));
}

export async function listVaultFiles(root: string): Promise<VaultFileEntry[]> {
  if (!isTauriRuntime()) {
    const out: VaultFileEntry[] = [];
    for (const [path, content] of memoryVault) {
      out.push({ path, size: content.length, mtime: Date.now(), hash: await sha256Hex(content) });
    }
    return out;
  }
  return tauriInvoke<VaultFileEntry[]>('list_vault_files', { root });
}

export async function listVaultTree(root: string): Promise<VaultTreeEntry[]> {
  if (!isTauriRuntime()) {
    for (const path of memoryVault.keys()) {
      ensureMemoryDirectory(parentDirectoryPath(path));
    }
    const directories = new Set(memoryVaultDirectories);
    const out: VaultTreeEntry[] = [];
    for (const directory of directories) {
      out.push({
        path: directory,
        name: basename(directory),
        kind: 'folder',
        parentPath: parentDirectoryPath(directory),
        ctime: Date.now(),
        mtime: Date.now(),
      });
    }
    for (const [path, content] of memoryVault) {
      out.push({
        path,
        name: basename(path),
        kind: 'file',
        parentPath: parentDirectoryPath(path),
        size: content.length,
        ctime: Date.now(),
        mtime: Date.now(),
        hash: await sha256Hex(content),
      });
    }
    return normalizeVaultTreeEntries(out).sort((left, right) =>
      left.path.localeCompare(right.path, 'zh-CN'),
    );
  }
  const entries = await tauriInvoke<RawVaultTreeEntry[]>('list_vault_tree', { root });
  return normalizeVaultTreeEntries(entries);
}

export async function readVaultFile(root: string, path: string): Promise<string> {
  if (!isTauriRuntime()) {
    return memoryVault.get(path) ?? '';
  }
  return tauriInvoke<string>('read_vault_file', { root, path });
}

/** 原子写本地文件。写后由调用方计算 hash 并更新 sync_state。 */
export async function atomicWriteFile(root: string, path: string, content: string): Promise<void> {
  if (!isTauriRuntime()) {
    const normalized = normalizeVaultPath(path);
    memoryVault.set(normalized, content);
    ensureMemoryDirectory(parentDirectoryPath(normalized));
    return;
  }
  await tauriInvoke<void>('atomic_write_file', { root, path, content });
}

export async function deleteVaultFile(root: string, path: string): Promise<boolean> {
  if (!isTauriRuntime()) {
    const normalized = normalizeVaultPath(path);
    memoryVault.delete(normalized);
    memoryVaultBytes.delete(normalized);
    return true;
  }
  return tauriInvoke<boolean>('delete_vault_file', { root, path });
}

export async function renameVaultFile(
  root: string,
  fromPath: string,
  toPath: string,
): Promise<void> {
  if (!isTauriRuntime()) {
    const from = normalizeVaultPath(fromPath);
    const to = normalizeVaultPath(toPath);
    const content = memoryVault.get(from);
    if (content === undefined) {
      throw new Error(`文件不存在: ${fromPath}`);
    }
    if (memoryVault.has(to)) {
      throw new Error(`文件已存在: ${toPath}`);
    }
    memoryVault.delete(from);
    memoryVault.set(to, content);
    ensureMemoryDirectory(parentDirectoryPath(to));
    return;
  }
  await tauriInvoke<void>('rename_vault_file', { root, fromPath, toPath });
}

/** 字节级原子写（附件缓存等二进制）：bytes→base64→Rust atomic_write_bytes。 */
export async function atomicWriteFileBytes(
  root: string,
  path: string,
  bytes: Uint8Array,
): Promise<void> {
  if (!isTauriRuntime()) {
    const normalized = normalizeVaultPath(path);
    memoryVaultBytes.set(normalized, bytes);
    ensureMemoryDirectory(parentDirectoryPath(normalized));
    return;
  }
  await tauriInvoke<void>('atomic_write_bytes', { root, path, b64: bytesToBase64(bytes) });
}

/** 字节级读（附件缓存等二进制）；缺失返回 null。 */
export async function readVaultFileBytes(
  root: string,
  path: string,
): Promise<Uint8Array | null> {
  if (!isTauriRuntime()) {
    return memoryVaultBytes.get(path) ?? null;
  }
  const b64 = await tauriInvoke<string | null>('read_vault_file_bytes', { root, path });
  return b64 ? base64ToBytes(b64) : null;
}

/** 探测本地文件是否存在（文本或二进制缓存）。 */
export async function existsVaultFile(root: string, path: string): Promise<boolean> {
  if (!isTauriRuntime()) {
    return memoryVault.has(path) || memoryVaultBytes.has(path);
  }
  return tauriInvoke<boolean>('exists_vault_file', { root, path });
}

export async function createVaultDirectory(root: string, path: string): Promise<void> {
  if (!isTauriRuntime()) {
    const normalized = normalizeVaultPath(path);
    if (!normalized) {
      return;
    }
    memoryVaultDirectories.add(normalized);
    ensureMemoryDirectory(parentDirectoryPath(normalized));
    return;
  }
  await tauriInvoke<void>('create_vault_directory', { root, path });
}

export async function renameVaultDirectory(
  root: string,
  fromPath: string,
  toPath: string,
): Promise<void> {
  if (!isTauriRuntime()) {
    const from = normalizeVaultPath(fromPath);
    const to = normalizeVaultPath(toPath);
    const nextDirectories = new Set<string>();
    for (const directory of memoryVaultDirectories) {
      if (directory === from || directory.startsWith(`${from}/`)) {
        nextDirectories.add(`${to}${directory.slice(from.length)}`);
      } else {
        nextDirectories.add(directory);
      }
    }
    memoryVaultDirectories.clear();
    nextDirectories.forEach((directory) => memoryVaultDirectories.add(directory));
    ensureMemoryDirectory(parentDirectoryPath(to));
    for (const [path, content] of Array.from(memoryVault.entries())) {
      if (path === from || path.startsWith(`${from}/`)) {
        memoryVault.delete(path);
        memoryVault.set(`${to}${path.slice(from.length)}`, content);
      }
    }
    for (const [path, bytes] of Array.from(memoryVaultBytes.entries())) {
      if (path === from || path.startsWith(`${from}/`)) {
        memoryVaultBytes.delete(path);
        memoryVaultBytes.set(`${to}${path.slice(from.length)}`, bytes);
      }
    }
    return;
  }
  await tauriInvoke<void>('rename_vault_directory', { root, fromPath, toPath });
}

export async function deleteVaultDirectory(
  root: string,
  path: string,
  recursive = false,
): Promise<void> {
  if (!isTauriRuntime()) {
    const normalized = normalizeVaultPath(path);
    if (!normalized) {
      return;
    }
    if (recursive) {
      for (const key of Array.from(memoryVault.keys())) {
        if (key === normalized || key.startsWith(`${normalized}/`)) {
          memoryVault.delete(key);
        }
      }
      for (const key of Array.from(memoryVaultBytes.keys())) {
        if (key === normalized || key.startsWith(`${normalized}/`)) {
          memoryVaultBytes.delete(key);
        }
      }
      for (const directory of Array.from(memoryVaultDirectories.values())) {
        if (directory === normalized || directory.startsWith(`${normalized}/`)) {
          memoryVaultDirectories.delete(directory);
        }
      }
      return;
    }
    memoryVaultDirectories.delete(normalized);
    return;
  }
  await tauriInvoke<void>('delete_vault_directory', { root, path, recursive });
}

/**
 * 启动 vault 监听。返回反注册函数；onChanged 在文件变化（含 Obsidian 外部编辑）时触发。
 * 非 Tauri 环境下为空操作。
 */
export async function startVaultWatch(
  root: string,
  onChanged: (paths: string[]) => void,
): Promise<() => void> {
  if (!isTauriRuntime()) {
    return () => undefined;
  }
  await tauriInvoke<void>('start_vault_watch', { root });
  const { listen } = await import('@tauri-apps/api/event');
  const unlisten = await listen<VaultChangePayload>('vault-change', (event) => {
    onChanged(event.payload.paths);
  });
  return async () => {
    unlisten();
    try {
      await tauriInvoke<void>('stop_vault_watch');
    } catch {
      /* ignore */
    }
  };
}
