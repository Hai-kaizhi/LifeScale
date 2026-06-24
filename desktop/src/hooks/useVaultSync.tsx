import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { message } from 'antd';
import { getDeviceId, getVaultEngineSingleton, isTauriRuntime, type ConflictEvent } from '../services/vault';
import type { VaultSyncStatus, WorkspaceSyncPreview } from '../shared/types/vault';
import { chooseMarkdownRootFolder, ensureDefaultVaultRoot, MEMORY_VAULT_ROOT } from '../services/desktopFileBridge';
import { ConflictResolutionModal } from '../components/vault/ConflictResolutionModal';
import { WorkspaceGate } from '../components/vault/WorkspaceGate';
import { SyncProgressDialog } from '../components/vault/SyncProgressDialog';
import { WorkspaceSyncPreviewModal } from '../components/vault/WorkspaceSyncPreviewModal';
import { useAuth } from './useAuth';
import { lazyBackfillOnAppOpen } from '../services/vault/settlementService';

const VAULT_ROOT_KEY = 'lifescale.vault.root';

export interface InitialSyncProgress {
  total: number;
  done: number;
  phase: VaultSyncStatus['phase'];
  message?: string;
}

interface VaultSyncContextValue {
  status: VaultSyncStatus;
  conflicts: ConflictEvent[];
  vaultRoot: string | null;
  chooseVaultFolder: () => Promise<void>;
  resolveKeepMine: (c: ConflictEvent) => Promise<void>;
  resolveKeepTheirs: (c: ConflictEvent) => Promise<void>;
  /** 前台同步进度（登录/选文件夹触发）；null 表示不展示。 */
  initialSync: InitialSyncProgress | null;
  dismissInitialSync: () => void;
}

const VaultSyncContext = createContext<VaultSyncContextValue | null>(null);

interface PendingWorkspacePreview {
  kind: 'login' | 'switch';
  root: string;
  preview: WorkspaceSyncPreview;
}

export function readVaultRoot(): string | null {
  try {
    return localStorage.getItem(VAULT_ROOT_KEY);
  } catch {
    return null;
  }
}

export function VaultSyncProvider({ children }: { children: ReactNode }) {
  const engine = getVaultEngineSingleton();
  const { status: authStatus, user } = useAuth();
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
  const [initialSync, setInitialSync] = useState<InitialSyncProgress | null>(null);
  const [workspacePreview, setWorkspacePreview] = useState<PendingWorkspacePreview | null>(null);
  const [previewConfirming, setPreviewConfirming] = useState(false);
  const [conflicts, setConflicts] = useState<ConflictEvent[]>([]);
  const [vaultRoot, setVaultRoot] = useState<string | null>(readVaultRoot());
  const [defaultRootStatus, setDefaultRootStatus] = useState<'checking' | 'ready' | 'failed'>(() =>
    readVaultRoot() ? 'ready' : 'checking',
  );
  const inited = useRef(false);
  const authPreviewKey = useRef<string | null>(null);

  useEffect(() => {
    const off = engine.onStatus(setStatus);
    return off;
  }, [engine]);

  useEffect(() => {
    const off = engine.onConflict((c) => setConflicts((prev) => [...prev.filter((x) => x.vaultPath !== c.vaultPath), c]));
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
        // fire-and-forget，失败静默，不阻塞应用启动。inited ref 保证只跑一次。
        void lazyBackfillOnAppOpen(defaultRoot).catch(() => undefined);
      } catch {
        setDefaultRootStatus('failed');
      }
    })();
  }, [engine]);

  /**
   * 前台同步：包裹 engine 操作，订阅 status 实时驱动同步任务中心；
   * 完成后短暂展示 100% 再自动关闭，失败时保留错误态提示。
   */
  const runWithProgress = useCallback(
    async (op: () => Promise<void>) => {
      const snapshot: InitialSyncProgress = { total: 0, done: 0, phase: 'scanning' };
      let failed = false;
      const off = engine.onStatus((s) => {
        snapshot.total = s.syncTotal;
        snapshot.done = s.syncDone;
        snapshot.phase = s.phase;
        snapshot.message = s.syncMessage;
        setInitialSync({ total: s.syncTotal, done: s.syncDone, phase: s.phase, message: s.syncMessage });
      });
      setInitialSync({ total: 0, done: 0, phase: 'scanning', message: '正在准备同步任务...' });
      try {
        await op();
      } catch (err) {
        failed = true;
        throw err;
      } finally {
        off();
        const phase = failed || snapshot.phase === 'error' ? 'error' : 'synced';
        setInitialSync({
          total: snapshot.total,
          done: snapshot.total,
          phase,
          message: phase === 'error' ? snapshot.message : '本地与云端已一致',
        });
        window.setTimeout(() => setInitialSync(null), phase === 'error' ? 2500 : 1000);
      }
    },
    [engine],
  );

  // 鉴权状态联动云同步开关：local 关闭（纯本地），authenticated 开启并补推积压 dirty（前台进度弹窗）。
  useEffect(() => {
    const enabled = authStatus === 'authenticated';
    engine.setCloudSync(enabled);
    if (!enabled || !vaultRoot) {
      if (!enabled) {
        authPreviewKey.current = null;
      }
      return;
    }
    const previewKey = `${user?.id ?? 'unknown'}:${vaultRoot}`;
    if (authPreviewKey.current === previewKey) {
      return;
    }
    authPreviewKey.current = previewKey;
    let cancelled = false;
    void (async () => {
      await engine.writeWorkspaceMeta({
        userId: user?.id,
        username: user?.username,
        deviceId: getDeviceId(),
      });
      const preview = await engine.previewWorkspaceSync(vaultRoot);
      if (!cancelled) {
        setWorkspacePreview({ kind: 'login', root: vaultRoot, preview });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [engine, authStatus, user?.id, user?.username, vaultRoot]);

  const dismissInitialSync = useCallback(() => setInitialSync(null), []);

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
    if (!root) return;
    if (root === vaultRoot) return;

    if (authStatus === 'authenticated' && vaultRoot) {
      await runWithProgress(() => engine.flushNow());
      const latest = engine.getStatus();
      if (latest.conflict > 0 || latest.pending > 0) {
        message.warning('当前空间仍有冲突或待同步项，请处理完成后再切换本地镜像目录。');
        return;
      }
    }

    if (authStatus === 'authenticated') {
      engine.setCloudSync(true);
      const preview = await engine.previewWorkspaceSync(root);
      setWorkspacePreview({ kind: 'switch', root, preview });
      return;
    }

    persistVaultRoot(root);
    await engine.init(root);
  }, [authStatus, engine, persistVaultRoot, runWithProgress, vaultRoot]);

  const handleConfirmWorkspacePreview = useCallback(async () => {
    if (!workspacePreview) return;
    const pending = workspacePreview;
    setPreviewConfirming(true);
    try {
      persistVaultRoot(pending.root);
      setWorkspacePreview(null);
      engine.setCloudSync(authStatus === 'authenticated');
      await engine.init(pending.root);
      if (authStatus === 'authenticated') {
        await engine.writeWorkspaceMeta({
          userId: user?.id,
          username: user?.username,
          deviceId: getDeviceId(),
        });
        await runWithProgress(() => engine.flushNow());
      }
    } catch {
      message.error('工作区同步初始化失败');
    } finally {
      setPreviewConfirming(false);
    }
  }, [authStatus, engine, persistVaultRoot, runWithProgress, user?.id, user?.username, workspacePreview]);

  const handleCancelWorkspacePreview = useCallback(() => {
    setWorkspacePreview(null);
  }, []);

  const resolveKeepMine = useCallback(async (c: ConflictEvent) => {
    await engine.resolveKeepMine(c.vaultPath, c.conflict.theirsHash ?? '');
    setConflicts((prev) => prev.filter((x) => x.vaultPath !== c.vaultPath));
  }, [engine]);
  const resolveKeepTheirs = useCallback(async (c: ConflictEvent) => {
    await engine.resolveKeepTheirs(c.vaultPath, c.conflict.theirsContent);
    setConflicts((prev) => prev.filter((x) => x.vaultPath !== c.vaultPath));
  }, [engine]);

  const value = useMemo<VaultSyncContextValue>(
    () => ({
      status,
      conflicts,
      vaultRoot,
      chooseVaultFolder,
      resolveKeepMine,
      resolveKeepTheirs,
      initialSync,
      dismissInitialSync,
    }),
    [
      status,
      conflicts,
      vaultRoot,
      chooseVaultFolder,
      resolveKeepMine,
      resolveKeepTheirs,
      initialSync,
      dismissInitialSync,
    ],
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
      {vaultRoot && conflicts.length > 0 && (
        <ConflictResolutionModal
          conflict={conflicts[0]}
          onKeepMine={() => void resolveKeepMine(conflicts[0])}
          onKeepTheirs={() => void resolveKeepTheirs(conflicts[0])}
        />
      )}
      <SyncProgressDialog sync={initialSync} onClose={dismissInitialSync} />
      <WorkspaceSyncPreviewModal
        open={Boolean(workspacePreview)}
        preview={workspacePreview?.preview ?? null}
        title={workspacePreview?.kind === 'switch' ? '切换本地镜像目录前预检' : '登录后云同步预检'}
        confirmLoading={previewConfirming}
        onConfirm={handleConfirmWorkspacePreview}
        onCancel={handleCancelWorkspacePreview}
      />
    </VaultSyncContext.Provider>
  );
}

export function useVaultSync(): VaultSyncContextValue {
  const ctx = useContext(VaultSyncContext);
  if (!ctx) throw new Error('useVaultSync 必须在 VaultSyncProvider 内使用');
  return ctx;
}
