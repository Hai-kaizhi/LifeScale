import {
  deleteVaultFile,
  downloadAttachment,
  getVaultChanges,
  getVaultFile,
  pushVaultFile,
  uploadAttachment,
} from './vaultApi';
import { syncDailyEntitiesOnce } from './dailyEntitySync';
import {
  atomicWriteFile,
  atomicWriteFileBytes,
  deleteVaultFile as localDeleteFile,
  existsVaultFile,
  listVaultFiles,
  readVaultFile,
  readVaultFileBytes,
  renameVaultFile,
  sha256Hex,
  startVaultWatch,
} from './vaultFileBridge';
import * as syncState from './syncState';
import type {
  ConflictView,
  VaultChangeSummary,
  VaultSyncStatus,
  WorkspaceSyncPreview,
} from '../../shared/types/vault';

const PUSH_DEBOUNCE_MS = 1500;
const PERIODIC_MS = 60_000;
const BACKOFF_MAX_MS = 30_000;

export interface ConflictEvent {
  vaultPath: string;
  mineContent: string;
  conflict: ConflictView;
}

type StatusListener = (s: VaultSyncStatus) => void;
type ConflictListener = (c: ConflictEvent) => void;
type FileChangedListener = (paths: string[]) => void;
type AttachmentAvailableListener = (hash: string) => void;

/**
 * Vault 同步引擎（单例）：编辑即时落本地 → 1.5s 防抖入队推送；
 * 触发源 = 本地文件变化(含 Obsidian 外部编辑)/启动对账/网络恢复/60s 定时/窗口聚焦；
 * 离线时待推送项持久化在 sync_state(pending)，重连自动重试（指数退避）；
 * 冲突不覆盖本地，弹出冲突事件交由 UI 解决。
 */
export class VaultSyncEngine {
  private root: string | null = null;
  private deviceId: string;
  private dirtyTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private selfWriteIgnore = new Set<string>();
  private statusListeners = new Set<StatusListener>();
  private conflictListeners = new Set<ConflictListener>();
  private fileChangedListeners = new Set<FileChangedListener>();
  private attachmentAvailableListeners = new Set<AttachmentAvailableListener>();
  /** 附件待上传队列：hash → ext（内存；离线粘贴的图在缓存+引用里不丢，联网补传）。 */
  private attachmentUploadQueue = new Map<string, string>();
  /** 进行中的懒拉取 hash，防重复并发。 */
  private attachmentFetchInflight = new Set<string>();
  private status: VaultSyncStatus = {
    online: typeof navigator !== 'undefined' ? navigator.onLine : true,
    pending: 0,
    conflict: 0,
    lastSyncAt: null,
    phase: 'idle',
    activeVaultPath: null,
    syncTotal: 0,
    syncDone: 0,
  };
  private ticking = false;
  private periodicTimer: ReturnType<typeof setInterval> | null = null;
  private unlistenWatch?: () => void;
  private onlineHandler = () => {
    this.setStatus({ online: true, phase: 'idle' });
    void this.tick();
  };
  private offlineHandler = () => this.setStatus({ online: false, phase: 'offline' });
  private visibilityHandler = () => {
    if (document.visibilityState === 'visible') void this.tick();
  };
  private backoff = 1000;
  /**
   * 云同步开关：本地态（未登录）关闭，仅做本地落盘 + dirty 标记；
   * 登录后开启，tick/push/pull 才真正发起云端请求。
   * onContentChange 始终即时落本地，故关闭期间本地不丢；开启后由 pushAllDirty 统一补推。
   */
  private cloudEnabled = false;

  constructor(deviceId: string) {
    this.deviceId = deviceId;
    window.addEventListener('online', this.onlineHandler);
    window.addEventListener('offline', this.offlineHandler);
    document.addEventListener('visibilitychange', this.visibilityHandler);
  }

  // ---- 对外 API ----

  onStatus(cb: StatusListener): () => void {
    this.statusListeners.add(cb);
    cb(this.status);
    return () => this.statusListeners.delete(cb);
  }

  getStatus(): VaultSyncStatus {
    return this.status;
  }

  onConflict(cb: ConflictListener): () => void {
    this.conflictListeners.add(cb);
    return () => this.conflictListeners.delete(cb);
  }

  /**
   * 订阅「文件内容变化」事件：仅外部（Obsidian 等）/远端 pull 改动触发；
   * 引擎自身写入（selfWriteIgnore）不触发，避免回环。供 useDailyDoc 等刷新内存模型。
   */
  onFileChanged(cb: FileChangedListener): () => void {
    this.fileChangedListeners.add(cb);
    return () => this.fileChangedListeners.delete(cb);
  }

  private emitFileChanged(paths: string[]): void {
    if (!paths.length) return;
    for (const cb of this.fileChangedListeners) cb(paths);
  }

  // ---- 附件（内容寻址，独立于 .md 同步流）----

  /** 附件本地缓存相对路径：<vault>/attachments/<hash>.<ext>（被 watcher 忽略，不进 .md 同步）。 */
  attachmentCachePath(hash: string, ext: string): string {
    return `attachments/${hash}.${ext}`;
  }

  /** 读附件本地缓存字节（供编辑器/预览渲染为 blob URL）；缺失返回 null。 */
  async readAttachmentBytes(hash: string, ext: string): Promise<Uint8Array | null> {
    if (!this.root) return null;
    try {
      return await readVaultFileBytes(this.root, this.attachmentCachePath(hash, ext));
    } catch {
      return null;
    }
  }

  /** 入队附件上传（粘图后调用）。联网 tick 时按 hash 去重上传到 CAS。 */
  enqueueAttachmentUpload(hash: string, ext: string): void {
    this.attachmentUploadQueue.set(hash, ext);
  }

  /** 订阅「附件可用」事件（懒拉取落盘后触发，供渲染器刷新占位为实图）。 */
  onAttachmentAvailable(cb: AttachmentAvailableListener): () => void {
    this.attachmentAvailableListeners.add(cb);
    return () => this.attachmentAvailableListeners.delete(cb);
  }

  private emitAttachmentAvailable(hash: string): void {
    for (const cb of this.attachmentAvailableListeners) cb(hash);
  }

  /**
   * 懒拉取附件：本地缓存缺失时，从云端按 hash 下载并写缓存，然后 emit 可用事件。
   * 离线/本地态暂不拉（渲染占位，联网后由 tick 触发或下次调用重试）。
   */
  async ensureAttachment(hash: string, ext: string): Promise<void> {
    if (!this.root) return;
    const cachePath = this.attachmentCachePath(hash, ext);
    if (await existsVaultFile(this.root, cachePath)) return;
    if (this.attachmentFetchInflight.has(hash)) return;
    if (!this.cloudEnabled || (typeof navigator !== 'undefined' && !navigator.onLine)) return;
    this.attachmentFetchInflight.add(hash);
    try {
      const bytes = await downloadAttachment(hash);
      if (!bytes) return; // 服务端暂无（对端尚未上传）
      await atomicWriteFileBytes(this.root, cachePath, bytes);
      this.emitAttachmentAvailable(hash);
    } catch {
      /* 联网后重试 */
    } finally {
      this.attachmentFetchInflight.delete(hash);
    }
  }

  /** flush 待上传附件（tick 中、cloudEnabled+online 时调用）。 */
  private async flushAttachmentUploads(): Promise<void> {
    if (!this.root || !this.cloudEnabled) return;
    if (typeof navigator !== 'undefined' && !navigator.onLine) return;
    for (const [hash, ext] of [...this.attachmentUploadQueue]) {
      try {
        const bytes = await readVaultFileBytes(this.root, this.attachmentCachePath(hash, ext));
        if (!bytes) {
          this.attachmentUploadQueue.delete(hash);
          continue;
        }
        const res = await uploadAttachment(bytes);
        if (res.success) this.attachmentUploadQueue.delete(hash);
      } catch {
        /* 留队下次 tick 重试 */
      }
    }
  }

  /** 开关云同步。本地态关闭：不 push/pull；登录后开启并 flushNow 补推积压。 */
  setCloudSync(enabled: boolean): void {
    this.cloudEnabled = enabled;
  }

  async writeWorkspaceMeta(meta: { userId?: number | null; username?: string | null; deviceId?: string | null }): Promise<void> {
    if (!this.root) return;
    await syncState.setMeta(this.root, 'workspace.boundAt', new Date().toISOString());
    await syncState.setMeta(this.root, 'workspace.deviceId', meta.deviceId ?? this.deviceId);
    if (meta.userId != null) await syncState.setMeta(this.root, 'workspace.userId', String(meta.userId));
    if (meta.username) await syncState.setMeta(this.root, 'workspace.username', meta.username);
  }

  async previewWorkspaceSync(root = this.root): Promise<WorkspaceSyncPreview> {
    const preview: WorkspaceSyncPreview = {
      root: root ?? '',
      cloudEnabled: this.cloudEnabled,
      localFiles: 0,
      remoteFiles: 0,
      sameFiles: 0,
      uploadFiles: 0,
      downloadFiles: 0,
      conflictFiles: 0,
      remoteDeletedFiles: 0,
      pendingAttachments: this.attachmentUploadQueue.size,
      dirtyFiles: 0,
      pendingFiles: 0,
      deletedFiles: 0,
    };
    if (!root) return preview;

    try {
      this.setStatus({ phase: 'scanning', syncMessage: '正在扫描本地工作区...', activeVaultPath: null, syncTotal: 0, syncDone: 0 });
      const localEntries = await listVaultFiles(root);
      const localByPath = new Map(localEntries.map((entry) => [entry.path, entry.hash]));
      preview.localFiles = localEntries.length;

      const [dirty, pending, deleted] = await Promise.all([
        syncState.listSyncState(root, 'dirty'),
        syncState.listSyncState(root, 'pending'),
        syncState.listSyncState(root, 'deleted'),
      ]);
      preview.dirtyFiles = dirty.length;
      preview.pendingFiles = pending.length;
      preview.deletedFiles = deleted.length;

      if (!this.cloudEnabled || (typeof navigator !== 'undefined' && !navigator.onLine)) {
        preview.uploadFiles = localEntries.length;
        this.setStatus({ phase: 'idle', syncMessage: undefined, activeVaultPath: null });
        return preview;
      }

      const remote = await this.collectRemoteChangesFromEpoch();
      const activeRemote = remote.filter((entry) => entry.status === 'active');
      const remoteByPath = new Map(activeRemote.map((entry) => [entry.vaultPath, entry]));
      preview.remoteFiles = activeRemote.length;
      preview.remoteDeletedFiles = remote.filter((entry) => entry.status === 'deleted').length;

      for (const [path, hash] of localByPath) {
        const remoteEntry = remoteByPath.get(path);
        if (!remoteEntry) {
          preview.uploadFiles += 1;
        } else if (remoteEntry.contentHash === hash) {
          preview.sameFiles += 1;
        } else {
          preview.conflictFiles += 1;
        }
      }
      for (const path of remoteByPath.keys()) {
        if (!localByPath.has(path)) preview.downloadFiles += 1;
      }
      this.setStatus({ phase: 'idle', syncMessage: undefined, activeVaultPath: null });
      return preview;
    } catch (err) {
      this.setStatus({ phase: 'error', syncMessage: '工作区预检失败', activeVaultPath: null });
      return {
        ...preview,
        failed: true,
        message: err instanceof Error ? err.message : '工作区预检失败',
      };
    }
  }

  async init(root: string): Promise<void> {
    this.root = root;
    // 重选文件夹时先清理旧 watcher/定时器，避免泄漏监听器
    void this.unlistenWatch?.();
    if (this.periodicTimer) {
      clearInterval(this.periodicTimer);
      this.periodicTimer = null;
    }
    this.unlistenWatch = await startVaultWatch(root, (paths) => {
      void this.onLocalChanged(paths);
    });
    this.periodicTimer = setInterval(() => void this.tick(), PERIODIC_MS);
    await this.reconcile();
  }

  dispose(): void {
    if (this.periodicTimer) clearInterval(this.periodicTimer);
    this.periodicTimer = null;
    void this.unlistenWatch?.();
    window.removeEventListener('online', this.onlineHandler);
    window.removeEventListener('offline', this.offlineHandler);
    document.removeEventListener('visibilitychange', this.visibilityHandler);
  }

  /** 编辑器内容变化：即时写本地 + 防抖入队推送。 */
  async onContentChange(vaultPath: string, content: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(vaultPath);
    await atomicWriteFile(this.root, vaultPath, content);
    const localHash = await sha256Hex(content);
    await syncState.upsertSyncState(this.root, vaultPath, localHash, 'dirty');
    void this.refreshPendingCount();
    this.enqueuePush(vaultPath);
  }

  /** 读取本地文件内容（编辑器加载用）。 */
  async readLocalFile(vaultPath: string): Promise<string> {
    if (!this.root) return '';
    try {
      return await readVaultFile(this.root, vaultPath);
    } catch {
      return '';
    }
  }

  /** 本地重命名文件：先真实落盘，再按“旧路径删除 + 新路径新增”进入同步队列。 */
  async renameLocalFile(fromPath: string, toPath: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(fromPath);
    this.selfWriteIgnore.add(toPath);
    await renameVaultFile(this.root, fromPath, toPath);
    await this.recordLocalFileRename(fromPath, toPath);
  }

  /** 文件夹重命名后补记子文件同步状态；文件本身已由调用方完成移动。 */
  async recordLocalFileRename(fromPath: string, toPath: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(fromPath);
    this.selfWriteIgnore.add(toPath);
    const previous = await syncState.getSyncState(this.root, fromPath);
    const content = await readVaultFile(this.root, toPath);
    const localHash = await sha256Hex(content);
    await syncState.upsertSyncState(
      this.root,
      fromPath,
      null,
      'deleted',
      previous?.baseVersion ?? null,
      previous?.localMtime ?? null,
    );
    await syncState.upsertSyncState(this.root, toPath, localHash, 'dirty');
    if (this.cloudEnabled && (typeof navigator === 'undefined' || navigator.onLine)) {
      this.enqueuePush(fromPath);
      this.enqueuePush(toPath);
    }
    void this.refreshPendingCount();
  }

  /** 本地删除一个文件并同步墓碑到云端。 */
  async deleteLocal(vaultPath: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(vaultPath);
    await localDeleteFile(this.root, vaultPath);
    await syncState.upsertSyncState(this.root, vaultPath, null, 'deleted');
    if (!this.cloudEnabled || (typeof navigator !== 'undefined' && !navigator.onLine)) {
      void this.refreshPendingCount();
      return;
    }
    try {
      const res = await deleteVaultFile(vaultPath, this.deviceId);
      if (res.success || res.code === 404) {
        await syncState.removeSyncState(this.root, vaultPath);
      }
    } catch {
      /* 离线或网络抖动：保留 deleted 墓碑，下次 tick 重试。 */
    }
    void this.refreshPendingCount();
  }

  /** 立即触发一次推送 + 拉取。 */
  async flushNow(): Promise<void> {
    await this.tick();
  }

  /** 冲突解决 - 保留本地：以 theirsHash 为基准重推本地内容，mine 成为新正本（theirs 已存于冲突副本）。 */
  async resolveKeepMine(vaultPath: string, theirsHash: string): Promise<void> {
    if (!this.root) return;
    let content: string;
    try {
      content = await readVaultFile(this.root, vaultPath);
    } catch {
      return;
    }
    const res = await pushVaultFile({ vaultPath, content, ifMatchHash: theirsHash, deviceId: this.deviceId });
    if (res.success && res.data && res.data.data) {
      this.selfWriteIgnore.add(vaultPath);
      await atomicWriteFile(this.root, vaultPath, res.data.data.content);
      const localHash = await sha256Hex(res.data.data.content);
      await syncState.upsertSyncState(this.root, vaultPath, localHash, 'clean', res.data.data.version);
      await syncState.markSynced(this.root, vaultPath, res.data.data.contentHash);
    }
    void this.refreshPendingCount();
  }

  /** 冲突解决 - 保留云端：把服务端内容写回本地并标记已同步。 */
  async resolveKeepTheirs(vaultPath: string, theirsContent: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(vaultPath);
    await atomicWriteFile(this.root, vaultPath, theirsContent);
    const localHash = await sha256Hex(theirsContent);
    await syncState.upsertSyncState(this.root, vaultPath, localHash, 'clean');
    await syncState.markSynced(this.root, vaultPath, localHash);
    void this.refreshPendingCount();
  }

  // ---- 内部 ----

  private enqueuePush(vaultPath: string): void {
    const prev = this.dirtyTimers.get(vaultPath);
    if (prev) clearTimeout(prev);
    this.dirtyTimers.set(
      vaultPath,
      setTimeout(() => {
        this.dirtyTimers.delete(vaultPath);
        void this.pushOne(vaultPath);
      }, PUSH_DEBOUNCE_MS),
    );
  }

  private async onLocalChanged(paths: string[]): Promise<void> {
    if (!this.root) return;
    const external: string[] = [];
    for (const path of paths) {
      if (this.selfWriteIgnore.delete(path)) continue; // 自身写入：忽略
      external.push(path);
      let content: string;
      try {
        content = await readVaultFile(this.root, path);
      } catch {
        const st = await syncState.getSyncState(this.root, path);
        if (st && st.status !== 'deleted') {
          await syncState.upsertSyncState(this.root, path, null, 'deleted', st.baseVersion, st.localMtime);
          this.enqueuePush(path);
        }
        continue;
      }
      const localHash = await sha256Hex(content);
      const st = await syncState.getSyncState(this.root, path);
      if (st && st.localHash === localHash && st.status === 'clean') continue; // 与已知一致
      await syncState.upsertSyncState(this.root, path, localHash, 'dirty');
      this.enqueuePush(path);
    }
    if (external.length) this.emitFileChanged(external);
    void this.refreshPendingCount();
  }

  /** 启动对账：扫描本地文件 vs sync_state，外部编辑或新增 → dirty。 */
  private async reconcile(): Promise<void> {
    if (!this.root) return;
    const entries = await listVaultFiles(this.root);
    const localPaths = new Set(entries.map((entry) => entry.path));
    for (const e of entries) {
      const st = await syncState.getSyncState(this.root, e.path);
      if (!st || st.localHash !== e.hash) {
        await syncState.upsertSyncState(this.root, e.path, e.hash, 'dirty');
      }
    }
    const knownRows = await Promise.all([
      syncState.listSyncState(this.root, 'clean'),
      syncState.listSyncState(this.root, 'dirty'),
      syncState.listSyncState(this.root, 'pending'),
      syncState.listSyncState(this.root, 'conflict'),
    ]);
    for (const row of knownRows.flat()) {
      if (!localPaths.has(row.vaultPath) && row.status !== 'conflict') {
        await syncState.upsertSyncState(this.root, row.vaultPath, null, 'deleted', row.baseVersion, row.localMtime);
      }
    }
    void this.refreshPendingCount();
  }

  private async tick(): Promise<void> {
    if (this.ticking || !this.root) return;
    if (!this.cloudEnabled) return; // 本地态：不 push/pull
    if (!navigator.onLine) {
      this.setStatus({ phase: 'offline', activeVaultPath: null });
      return;
    }
    this.ticking = true;
    try {
      this.setStatus({ phase: 'scanning', syncMessage: '正在扫描本地变更...', activeVaultPath: null, syncTotal: 0, syncDone: 0 });
      await this.reconcile();
      this.setStatus({ phase: 'pushing', syncMessage: '正在上传本地修改...', activeVaultPath: null, syncTotal: 0, syncDone: 0 });
      await this.pushAllDirty();
      this.setStatus({ phase: 'pulling', syncMessage: '正在拉取云端变更...', activeVaultPath: null });
      await this.applyPull();
      this.setStatus({ phase: 'attachments', syncMessage: '正在同步图片附件...', activeVaultPath: null });
      await this.flushAttachmentUploads();
      // 当天未沉淀实体同步（docs/09 §9.3，LWW；settled=0 才同步，沉淀后转文件同步）
      await syncDailyEntitiesOnce(this.root, this.deviceId);
      this.setStatus({
        phase: 'synced',
        syncMessage: '本地与云端已一致',
        activeVaultPath: null,
        lastSyncAt: new Date().toISOString(),
        syncDone: this.status.syncTotal,
      });
      this.backoff = 1000;
    } catch {
      this.setStatus({ phase: 'error', syncMessage: '同步失败，将在后台自动重试', activeVaultPath: null });
      this.backoff = Math.min(this.backoff * 2, BACKOFF_MAX_MS);
      setTimeout(() => void this.tick(), this.backoff);
    } finally {
      this.ticking = false;
    }
  }

  private async pushAllDirty(): Promise<void> {
    if (!this.root) return;
    const dirty = await syncState.listSyncState(this.root, 'dirty');
    const pending = await syncState.listSyncState(this.root, 'pending');
    const deleted = await syncState.listSyncState(this.root, 'deleted');
    this.setStatus({ syncTotal: dirty.length + pending.length + deleted.length, syncDone: 0 });
    for (const row of [...dirty, ...pending, ...deleted]) {
      await this.pushOne(row.vaultPath);
      this.setStatus({ syncDone: this.status.syncDone + 1 });
    }
  }

  private async pushOne(vaultPath: string): Promise<void> {
    if (!this.root) return;
    if (!this.cloudEnabled) return; // 本地态：文件已落盘 + dirty，留待登录后补推
    this.setStatus({ activeVaultPath: vaultPath });
    try {
      const st = await syncState.getSyncState(this.root, vaultPath);
      if (!navigator.onLine) {
        if (st?.status !== 'deleted') {
          await syncState.upsertSyncState(this.root, vaultPath, st?.localHash ?? null, 'pending');
        }
        return;
      }
      if (st?.status === 'deleted') {
        const res = await deleteVaultFile(vaultPath, this.deviceId);
        if (res.success || res.code === 404) {
          await syncState.removeSyncState(this.root, vaultPath);
        }
        void this.refreshPendingCount();
        return;
      }
      let content: string;
      try {
        content = await readVaultFile(this.root, vaultPath);
      } catch {
        if (st) {
          await syncState.upsertSyncState(this.root, vaultPath, null, 'deleted', st.baseVersion, st.localMtime);
          void this.refreshPendingCount();
        }
        return;
      }
      const localHash = await sha256Hex(content);
      const ifMatchHash = st?.syncedHash ?? null;
      if (!ifMatchHash) {
        const remote = await getVaultFile(vaultPath);
        if (remote.success && remote.data && (remote.data.contentHash === localHash || remote.data.content === content)) {
          await syncState.upsertSyncState(this.root, vaultPath, localHash, 'clean', remote.data.version);
          await syncState.markSynced(this.root, vaultPath, remote.data.contentHash);
          void this.refreshPendingCount();
          return;
        }
      }
      const res = await pushVaultFile({ vaultPath, content, ifMatchHash, deviceId: this.deviceId });
      if (!res.success || !res.data) {
        await syncState.upsertSyncState(this.root, vaultPath, null, 'pending'); // 网络错误，待重试
        return;
      }
      const result = res.data;
      if (result.outcome === 'conflict' && result.conflict) {
        await syncState.upsertSyncState(this.root, vaultPath, null, 'conflict');
        void this.refreshPendingCount();
        for (const cb of this.conflictListeners) cb({ vaultPath, mineContent: content, conflict: result.conflict });
        return;
      }
      // created / ok / merged
      if (result.data && (result.outcome === 'merged' || result.outcome === 'ok') && result.data.content !== content) {
        // 服务端内容（合并结果）与本地不同 → 回写本地
        this.selfWriteIgnore.add(vaultPath);
        await atomicWriteFile(this.root, vaultPath, result.data.content);
        const localHash = await sha256Hex(result.data.content);
        await syncState.upsertSyncState(this.root, vaultPath, localHash, 'clean', result.data.version);
      }
      const serverHash = result.data?.contentHash ?? null;
      if (serverHash) await syncState.markSynced(this.root, vaultPath, serverHash);
      void this.refreshPendingCount();
    } finally {
      if (this.status.activeVaultPath === vaultPath) {
        this.setStatus({ activeVaultPath: null });
      }
    }
  }

  /** 两遍拉取：先收集全部变更摘要（得准确总量），再逐条应用并报进度。 */
  private async collectChanges(): Promise<{
    changes: VaultChangeSummary[];
    finalCursor: string | undefined;
  }> {
    if (!this.root) return { changes: [], finalCursor: undefined };
    let since = (await syncState.getLastCursor(this.root)) ?? undefined;
    const all: VaultChangeSummary[] = [];
    let finalCursor: string | undefined;
    for (let guard = 0; guard < 50; guard++) {
      const res = await getVaultChanges(since);
      if (!res.success || !res.data) break;
      all.push(...res.data.changes);
      since = res.data.nextCursor;
      finalCursor = res.data.nextCursor;
      if (!res.data.hasMore) break;
    }
    return { changes: all, finalCursor };
  }

  private async collectRemoteChangesFromEpoch(): Promise<VaultChangeSummary[]> {
    let since: string | undefined = new Date(0).toISOString();
    const all: VaultChangeSummary[] = [];
    for (let guard = 0; guard < 50; guard++) {
      const res = await getVaultChanges(since, 500);
      if (!res.success || !res.data) break;
      all.push(...res.data.changes);
      since = res.data.nextCursor;
      if (!res.data.hasMore) break;
    }
    return all;
  }

  private async applyPull(): Promise<void> {
    if (!this.root) return;
    if (!this.cloudEnabled) return; // 本地态：不拉取
    const { changes, finalCursor } = await this.collectChanges();
    this.setStatus({ syncTotal: this.status.syncTotal + changes.length, activeVaultPath: null });
    for (const c of changes) {
      this.setStatus({ phase: 'applying', syncMessage: `正在应用 ${c.vaultPath}`, activeVaultPath: c.vaultPath });
      await this.applyChange(c);
      this.setStatus({ syncDone: this.status.syncDone + 1 });
    }
    if (finalCursor) await syncState.setLastCursor(this.root, finalCursor);
    this.setStatus({ activeVaultPath: null });
    void this.refreshPendingCount();
  }

  private async applyChange(change: VaultChangeSummary): Promise<void> {
    if (!this.root) return;
    if (change.status === 'deleted') {
      const st = await syncState.getSyncState(this.root, change.vaultPath);
      if (st && (st.status === 'dirty' || st.status === 'pending' || st.status === 'conflict' || st.status === 'deleted')) {
        return; // 本地仍有未决状态：不让云端删除覆盖本地决策。
      }
      this.selfWriteIgnore.add(change.vaultPath);
      await localDeleteFile(this.root, change.vaultPath);
      await syncState.removeSyncState(this.root, change.vaultPath);
      return;
    }
    const st = await syncState.getSyncState(this.root, change.vaultPath);
    if (st && (st.status === 'dirty' || st.status === 'pending' || st.status === 'conflict' || st.status === 'deleted')) {
      return; // 本地有未推送改动：不覆盖，交由推送冲突处理
    }
    if (st && st.syncedHash === change.contentHash) return; // 已是最新
    const fres = await getVaultFile(change.vaultPath);
    if (!fres.success || !fres.data) return;
    this.selfWriteIgnore.add(change.vaultPath);
    await atomicWriteFile(this.root, change.vaultPath, fres.data.content);
    const localHash = await sha256Hex(fres.data.content);
    await syncState.upsertSyncState(this.root, change.vaultPath, localHash, 'clean', fres.data.version);
    await syncState.markSynced(this.root, change.vaultPath, fres.data.contentHash);
    this.emitFileChanged([change.vaultPath]);
  }

  private async refreshPendingCount(): Promise<void> {
    if (!this.root) return;
    const dirty = await syncState.listSyncState(this.root, 'dirty');
    const pending = await syncState.listSyncState(this.root, 'pending');
    const deleted = await syncState.listSyncState(this.root, 'deleted');
    const conflict = await syncState.listSyncState(this.root, 'conflict');
    this.setStatus({ pending: dirty.length + pending.length + deleted.length, conflict: conflict.length });
  }

  private setStatus(partial: Partial<VaultSyncStatus>): void {
    this.status = { ...this.status, ...partial };
    for (const cb of this.statusListeners) cb(this.status);
  }
}

let engineInstance: VaultSyncEngine | null = null;

export function getVaultEngine(deviceId: string): VaultSyncEngine {
  if (!engineInstance) engineInstance = new VaultSyncEngine(deviceId);
  return engineInstance;
}
