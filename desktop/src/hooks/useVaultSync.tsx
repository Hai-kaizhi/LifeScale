import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { getVaultEngineSingleton, isTauriRuntime } from '../services/vault';
import type { VaultSyncStatus } from '../shared/types/vault';
import { chooseMarkdownRootFolder, ensureDefaultVaultRoot, MEMORY_VAULT_ROOT } from '../services/desktopFileBridge';
import { WorkspaceGate } from '../components/vault/WorkspaceGate';
import { lazyBackfillOnAppOpen } from '../services/vault/settlementService';

const VAULT_ROOT_KEY = 'lifescale.vault.root';

interface VaultSyncContextValue {
  status: VaultSyncStatus;
  vaultRoot: string | null;
  chooseVaultFolder: () => Promise<void>;
}

const VaultSyncContext = createContext<VaultSyncContextValue | null>(null);

export function readVaultRoot(): string | null {
  try {
    return localStorage.getItem(VAULT_ROOT_KEY);
  } catch {
    return null;
  }
}

/**
 * 本地工作区 Provider（开源本地版）。
 *
 * 私有版在此承载云同步：登录态联动 cloudSync 开关、登录/切换文件夹触发预检弹窗、
 * 冲突解决、前台同步进度。开源版已移除全部网络逻辑，仅保留：
 * - 本地 vaultRoot 初始化（默认工作区 + 选择文件夹）。
 * - 引擎状态订阅（pending/conflict 计数，本地态下恒为 0）。
 * - 打开应用时惰性补沉淀（本地）。
 */
export function VaultSyncProvider({ children }: { children: ReactNode }) {
  const engine = getVaultEngineSingleton();
  const [status, setStatus] = useState<VaultSyncStatus>({
    online: typeof navigator !== 'undefined' ? navigator.onLine : true,
    pending: 0,
    conflict: 0,
    lastSyncAt: null,
    phase: 'idle',
    activeVaultPath: null,
    syncTotal: 0,
    syncDone: 0,
  });
  const [vaultRoot, setVaultRoot] = useState<string | null>(readVaultRoot());
  const [defaultRootStatus, setDefaultRootStatus] = useState<'checking' | 'ready' | 'failed'>(() =>
    readVaultRoot() ? 'ready' : 'checking',
  );
  const inited = useRef(false);

  useEffect(() => {
    const off = engine.onStatus(setStatus);
    return off;
  }, [engine]);

  useEffect(() => {
    if (inited.current) return;
    inited.current = true;
    const root = readVaultRoot();
    if (root) {
      setDefaultRootStatus('ready');
      void engine
        .init(root)
        .then(() => lazyBackfillOnAppOpen(root))
        .catch(() => undefined);
      return;
    }
    void (async () => {
      try {
        const defaultRoot = await ensureDefaultVaultRoot();
        try {
          localStorage.setItem(VAULT_ROOT_KEY, defaultRoot);
        } catch {
          /* ignore */
        }
        setVaultRoot(defaultRoot);
        setDefaultRootStatus('ready');
        await engine.init(defaultRoot);
        // 惰性补沉淀：打开应用时扫描「过去日期且未沉淀」的记录逐个沉淀（docs/09 §7.3）。
        void lazyBackfillOnAppOpen(defaultRoot).catch(() => undefined);
      } catch {
        setDefaultRootStatus('failed');
      }
    })();
  }, [engine]);

  const persistVaultRoot = useCallback((root: string) => {
    try {
      localStorage.setItem(VAULT_ROOT_KEY, root);
    } catch {
      /* ignore */
    }
    setVaultRoot(root);
  }, []);

  const chooseVaultFolder = useCallback(async () => {
    let root: string | null;
    if (isTauriRuntime()) {
      root = await chooseMarkdownRootFolder();
    } else {
      root = MEMORY_VAULT_ROOT;
    }
    if (!root || root === vaultRoot) return;
    persistVaultRoot(root);
    await engine.init(root);
  }, [engine, persistVaultRoot, vaultRoot]);

  const value = useMemo<VaultSyncContextValue>(
    () => ({ status, vaultRoot, chooseVaultFolder }),
    [status, vaultRoot, chooseVaultFolder],
  );

  return (
    <VaultSyncContext.Provider value={value}>
      {vaultRoot ? (
        children
      ) : defaultRootStatus === 'checking' ? (
        <div style={{ display: 'grid', placeItems: 'center', minHeight: '100vh', color: '#64748b' }}>
          正在准备本地工作区...
        </div>
      ) : (
        <WorkspaceGate onChoose={() => void chooseVaultFolder()} />
      )}
    </VaultSyncContext.Provider>
  );
}

export function useVaultSync(): VaultSyncContextValue {
  const ctx = useContext(VaultSyncContext);
  if (!ctx) throw new Error('useVaultSync 必须在 VaultSyncProvider 内使用');
  return ctx;
}
