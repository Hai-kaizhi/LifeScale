import type { SyncStateRow, SyncStatus } from '../../shared/types/vault';

/**
 * 本地同步状态索引封装。
 *
 * 开源本地版移除了后端同步层（含原 <vault>/.lifescale/sync.db 的 Tauri 持久化
 * 命令），这里改为纯内存 Map 兜底。它仍然用于跟踪本地文件的 hash / dirty 标记，
 * 供 reconcile 观察本地待写状态；不再有任何云端游标语义。
 */
const memoryState = new Map<string, SyncStateRow>();
const memoryMeta = new Map<string, string>();

function memoryKey(root: string, vaultPath: string): string {
  return `${root}:${vaultPath}`;
}

export async function upsertSyncState(
  root: string,
  vaultPath: string,
  localHash: string | null,
  status: SyncStatus,
  _baseVersion: number | null = null,
  _localMtime: number | null = null,
): Promise<void> {
  const key = memoryKey(root, vaultPath);
  const prev = memoryState.get(key);
  memoryState.set(key, {
    vaultPath,
    localHash,
    syncedHash: prev?.syncedHash ?? (status === 'clean' ? localHash : null),
    status,
    baseVersion: _baseVersion,
    localMtime: _localMtime,
  });
}

export async function getSyncState(root: string, vaultPath: string): Promise<SyncStateRow | null> {
  return memoryState.get(memoryKey(root, vaultPath)) ?? null;
}

export async function markSynced(root: string, vaultPath: string, syncedHash: string): Promise<void> {
  const row = memoryState.get(memoryKey(root, vaultPath));
  if (row) {
    row.syncedHash = syncedHash;
    row.status = 'clean';
  }
}

export async function listSyncState(root: string, status: SyncStatus): Promise<SyncStateRow[]> {
  const prefix = `${root}:`;
  return Array.from(memoryState.entries())
    .filter(([key, row]) => key.startsWith(prefix) && row.status === status)
    .map(([, row]) => row);
}

/** 列出某工作区下全部 sync_state 行（不按状态过滤）。 */
export async function listAllSyncState(root: string): Promise<SyncStateRow[]> {
  const prefix = `${root}:`;
  return Array.from(memoryState.entries())
    .filter(([key]) => key.startsWith(prefix))
    .map(([, row]) => row);
}

export async function removeSyncState(root: string, vaultPath: string): Promise<void> {
  memoryState.delete(memoryKey(root, vaultPath));
}

export async function getMeta(root: string, key: string): Promise<string | null> {
  return memoryMeta.get(`${root}:${key}`) ?? null;
}

export async function setMeta(root: string, key: string, value: string): Promise<void> {
  memoryMeta.set(`${root}:${key}`, value);
}
