import {
  atomicWriteFile,
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
import type { ConflictView, VaultSyncStatus } from '../../shared/types/vault';

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
 * Vault 同步引擎（纯本地，单例）。
 *
 * 开源本地版移除了全部云端同步层：编辑即时落本地，外部（如 Obsidian）改动经
 * watcher 触发 onFileChanged 通知 UI 刷新内存模型。reconcile 维护本地文件
 * hash 索引（dirty/clean 标记）以便观察本地待写状态，但不再有任何推送/拉取。
 * online/offline 仅作为状态展示，不再触发任何网络动作。
 */
export class VaultSyncEngine {
  private root: string | null = null;
  private selfWriteIgnore = new Set<string>();
  private statusListeners = new Set<StatusListener>();
  private conflictListeners = new Set<ConflictListener>();
  private fileChangedListeners = new Set<FileChangedListener>();
  private attachmentAvailableListeners = new Set<AttachmentAvailableListener>();
  /** 附件待上传队列：hash → ext（纯本地态保留接口；不再实际上传）。 */
  private attachmentUploadQueue = new Map<string, string>();
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
  private unlistenWatch?: () => void;
  private onlineHandler = () => this.setStatus({ online: true });
  private offlineHandler = () => this.setStatus({ online: false, phase: 'offline' });

  // deviceId 在私有版用于云推送标识；开源本地版无网络调用，仅保留构造参数以兼容工厂签名。
  constructor(_deviceId: string) {
    window.addEventListener('online', this.onlineHandler);
    window.addEventListener('offline', this.offlineHandler);
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

  /** 冲突事件注册（纯本地态不会触发，保留接口供 UI 订阅）。 */
  onConflict(cb: ConflictListener): () => void {
    this.conflictListeners.add(cb);
    return () => this.conflictListeners.delete(cb);
  }

  /**
   * 订阅「文件内容变化」事件：仅外部（Obsidian 等）改动触发；
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

  /** 入队附件上传（粘图后调用）。纯本地态仅记录，不实际上传。 */
  enqueueAttachmentUpload(hash: string, ext: string): void {
    this.attachmentUploadQueue.set(hash, ext);
  }

  /** 订阅「附件可用」事件（外部写入缓存后触发，供渲染器刷新占位为实图）。 */
  onAttachmentAvailable(cb: AttachmentAvailableListener): () => void {
    this.attachmentAvailableListeners.add(cb);
    return () => this.attachmentAvailableListeners.delete(cb);
  }

  private emitAttachmentAvailable(hash: string): void {
    for (const cb of this.attachmentAvailableListeners) cb(hash);
  }

  /**
   * 确保附件可用（纯本地）。
   * 本地缓存命中即成功；缺失时不做任何下载（无云端），交由外部写入缓存后由
   * onAttachmentAvailable 通知。保留方法签名供编辑器按需调用。
   */
  async ensureAttachment(hash: string, ext: string): Promise<void> {
    if (!this.root) return;
    const cachePath = this.attachmentCachePath(hash, ext);
    if (await existsVaultFile(this.root, cachePath)) {
      this.emitAttachmentAvailable(hash);
    }
    // 纯本地态：缺失即缺失，不发起任何下载。
  }

  async init(root: string): Promise<void> {
    this.root = root;
    // 重选文件夹时先清理旧 watcher，避免泄漏监听器
    void this.unlistenWatch?.();
    this.unlistenWatch = await startVaultWatch(root, (paths) => {
      void this.onLocalChanged(paths);
    });
    await this.reconcile();
  }

  dispose(): void {
    void this.unlistenWatch?.();
    window.removeEventListener('online', this.onlineHandler);
    window.removeEventListener('offline', this.offlineHandler);
  }

  /** 编辑器内容变化：即时写本地 + 更新本地 hash 索引。 */
  async onContentChange(vaultPath: string, content: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(vaultPath);
    await atomicWriteFile(this.root, vaultPath, content);
    const localHash = await sha256Hex(content);
    await syncState.upsertSyncState(this.root, vaultPath, localHash, 'dirty');
    void this.refreshPendingCount();
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

  /** 本地重命名文件：先真实落盘，再按“旧路径删除 + 新路径新增”更新本地索引。 */
  async renameLocalFile(fromPath: string, toPath: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(fromPath);
    this.selfWriteIgnore.add(toPath);
    await renameVaultFile(this.root, fromPath, toPath);
    await this.recordLocalFileRename(fromPath, toPath);
  }

  /** 文件夹重命名后补记子文件索引；文件本身已由调用方完成移动。 */
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
    void this.refreshPendingCount();
  }

  /** 本地删除一个文件并更新索引。 */
  async deleteLocal(vaultPath: string): Promise<void> {
    if (!this.root) return;
    this.selfWriteIgnore.add(vaultPath);
    await localDeleteFile(this.root, vaultPath);
    await syncState.upsertSyncState(this.root, vaultPath, null, 'deleted');
    await syncState.removeSyncState(this.root, vaultPath);
    void this.refreshPendingCount();
  }

  // ---- 内部 ----

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
        }
        continue;
      }
      const localHash = await sha256Hex(content);
      const st = await syncState.getSyncState(this.root, path);
      if (st && st.localHash === localHash && st.status === 'clean') continue; // 与已知一致
      await syncState.upsertSyncState(this.root, path, localHash, 'dirty');
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
