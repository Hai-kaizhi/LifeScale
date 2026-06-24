import { getVaultEngine } from './syncEngine';

export { VaultSyncEngine, getVaultEngine } from './syncEngine';
export type { ConflictEvent } from './syncEngine';
export * from './vaultApi';
export { sha256Hex, isTauriRuntime } from './vaultFileBridge';
export { threeWayMerge } from './merge';
export type { MergeResult } from './merge';

const DEVICE_ID_KEY = 'lifescale.device.id';

/** 取（必要时生成并持久化）本机稳定 deviceId。 */
export function getDeviceId(): string {
  try {
    let id = localStorage.getItem(DEVICE_ID_KEY);
    if (!id) {
      const rand = typeof crypto !== 'undefined' && 'randomUUID' in crypto ? crypto.randomUUID() : `dev-${Date.now()}`;
      id = rand;
      localStorage.setItem(DEVICE_ID_KEY, id);
    }
    return id;
  } catch {
    return 'dev-unknown';
  }
}

/** 单例同步引擎（基于本机 deviceId）。 */
export function getVaultEngineSingleton(): ReturnType<typeof getVaultEngine> {
  return getVaultEngine(getDeviceId());
}
