import type { SyncStateRow, SyncStatus } from '../../shared/types/vault';
import { isTauriRuntime, tauriInvoke } from './vaultFileBridge';

/**
 * 本地同步状态索引封装（<vault>/.lifescale/sync.db via Tauri）。
 * 非 Tauri 环境用内存 Map 兜底。
 */
const memoryState = new Map<string, SyncStateRow>();
const memoryMeta = new Map<string, string>();
const ALL_SYNC_STATUSES: SyncStatus[] = ['clean', 'dirty', 'pending', 'conflict', 'deleted'];

interface SyncStateOut {
  vaultPath: string;
  localHash: string | null;
  syncedHash: string | null;
  status: string;
  baseVersion: number | null;
  localMtime: number | null;
}

function toRow(o: SyncStateOut): SyncStateRow {
  return { ...o, status: o.status as SyncStatus };
}

function memoryKey(root: string, vaultPath: string): string {
  return `${root}:${vaultPath}`;
}

export async function upsertSyncState(
  root: string,
  vaultPath: string,
  localHash: string | null,
  status: SyncStatus,
  baseVersion: number | null = null,
  localMtime: number | null = null,
): Promise<void> {
  if (!isTauriRuntime()) {
    const key = memoryKey(root, vaultPath);
    const prev = memoryState.get(key);
    memoryState.set(key, {
      vaultPath,
      localHash,
      syncedHash: prev?.syncedHash ?? (status === 'clean' ? localHash : null),
      status,
      baseVersion,
      localMtime,
    });
    return;
  }
  await tauriInvoke<void>('sync_state_upsert', { root, vaultPath, localHash, status, baseVersion, localMtime });
}

export async function getSyncState(root: string, vaultPath: string): Promise<SyncStateRow | null> {
  if (!isTauriRuntime()) {
    return memoryState.get(memoryKey(root, vaultPath)) ?? null;
  }
  const r = await tauriInvoke<SyncStateOut | null>('sync_state_get', { root, vaultPath });
  return r ? toRow(r) : null;
}

export async function markSynced(root: string, vaultPath: string, syncedHash: string): Promise<void> {
  if (!isTauriRuntime()) {
    const row = memoryState.get(memoryKey(root, vaultPath));
    if (row) {
      row.syncedHash = syncedHash;
      row.status = 'clean';
    }
    return;
  }
  await tauriInvoke<void>('sync_state_mark_synced', { root, vaultPath, syncedHash });
}

export async function listSyncState(root: string, status: SyncStatus): Promise<SyncStateRow[]> {
  if (!isTauriRuntime()) {
    const prefix = `${root}:`;
    return Array.from(memoryState.entries())
      .filter(([key, row]) => key.startsWith(prefix) && row.status === status)
      .map(([, row]) => row);
  }
  const rows = await tauriInvoke<SyncStateOut[]>('sync_state_list', { root, status });
  return rows.map(toRow);
}

export async function listAllSyncState(root: string): Promise<SyncStateRow[]> {
  const rows = await Promise.all(ALL_SYNC_STATUSES.map((status) => listSyncState(root, status)));
  return rows.flat();
}

export async function removeSyncState(root: string, vaultPath: string): Promise<void> {
  if (!isTauriRuntime()) {
    memoryState.delete(memoryKey(root, vaultPath));
    return;
  }
  await tauriInvoke<void>('sync_state_remove', { root, vaultPath });
}

export async function getMeta(root: string, key: string): Promise<string | null> {
  if (!isTauriRuntime()) return memoryMeta.get(`${root}:${key}`) ?? null;
  return tauriInvoke<string | null>('sync_meta_get', { root, key });
}

export async function setMeta(root: string, key: string, value: string): Promise<void> {
  if (!isTauriRuntime()) {
    memoryMeta.set(`${root}:${key}`, value);
    return;
  }
  await tauriInvoke<void>('sync_meta_set', { root, key, value });
}

export async function getLastCursor(root: string): Promise<string | null> {
  if (!isTauriRuntime()) return null;
  return tauriInvoke<string | null>('sync_last_cursor', { root });
}

export async function setLastCursor(root: string, cursor: string): Promise<void> {
  if (!isTauriRuntime()) return;
  await tauriInvoke<void>('sync_set_cursor', { root, cursor });
}
