/** Vault 同步相关类型，与后端 com.lifescale.backend.vault.dto 对齐。 */

export type VaultOutcome = 'created' | 'ok' | 'merged' | 'conflict';

export interface VaultFileData {
  vaultPath: string;
  content: string;
  contentHash: string;
  version: number;
  serverMtime: string;
  size: number;
}

export interface VaultChangeSummary {
  vaultPath: string;
  contentHash: string;
  version: number;
  serverMtime: string;
  status: 'active' | 'deleted';
  size: number;
}

export interface VaultChangesData {
  changes: VaultChangeSummary[];
  serverTime: string;
  nextCursor: string;
  hasMore: boolean;
}

export interface ConflictView {
  baseHash: string | null;
  theirsHash: string | null;
  theirsContent: string;
  conflictCopyPath: string;
  conflictId: number | null;
}

export interface VaultPushPayload {
  vaultPath: string;
  content: string;
  ifMatchHash?: string | null;
  deviceId?: string | null;
}

export interface VaultPushResult {
  outcome: VaultOutcome;
  data: VaultFileData | null;
  conflict: ConflictView | null;
}

export interface VaultVersionSummary {
  version: number;
  contentHash: string;
  size: number;
  deviceId: string | null;
  createdAt: string;
}

/** Tauri 侧返回的本地文件条目。 */
export interface VaultFileEntry {
  path: string;
  size: number;
  mtime: number;
  hash: string;
}

export type VaultNodeKind = 'file' | 'folder';

export interface VaultTreeEntry {
  path: string;
  name: string;
  kind: VaultNodeKind;
  parentPath: string | null;
  size?: number;
  ctime?: number;
  mtime?: number;
  hash?: string;
}

export type SyncStatus = 'clean' | 'dirty' | 'pending' | 'conflict' | 'deleted';

/** 本地同步状态索引行（<vault>/.lifescale/sync.db）。 */
export interface SyncStateRow {
  vaultPath: string;
  localHash: string | null;
  syncedHash: string | null;
  status: SyncStatus;
  baseVersion: number | null;
  localMtime: number | null;
}

/** 同步引擎对外的整体状态，供顶栏徽标渲染。 */
export interface VaultSyncStatus {
  online: boolean;
  pending: number;
  conflict: number;
  lastSyncAt: string | null;
  phase:
    | 'idle'
    | 'scanning'
    | 'pushing'
    | 'pulling'
    | 'applying'
    | 'attachments'
    | 'synced'
    | 'offline'
    | 'error';
  /** 当前同步阶段的用户可读说明。 */
  syncMessage?: string;
  /** 当前正在处理的 vault 路径，用于目录表格显示精确同步中状态。 */
  activeVaultPath?: string | null;
  /** 本次同步预计总量（待推送 + 待拉取 + 附件），供进度条。 */
  syncTotal: number;
  /** 本次同步已处理数，供进度条。 */
  syncDone: number;
}

/** 登录或切换工作区前的本地/云端差异预检结果。 */
export interface WorkspaceSyncPreview {
  root: string;
  cloudEnabled: boolean;
  localFiles: number;
  remoteFiles: number;
  sameFiles: number;
  uploadFiles: number;
  downloadFiles: number;
  conflictFiles: number;
  remoteDeletedFiles: number;
  pendingAttachments: number;
  dirtyFiles: number;
  pendingFiles: number;
  deletedFiles: number;
  failed?: boolean;
  message?: string;
}

/** Vault 监听事件载荷（Tauri emit "vault-change"）。 */
export interface VaultChangePayload {
  paths: string[];
}

/** 附件上传结果（POST /api/vault/attachments）。 */
export interface AttachmentUploadResult {
  hash: string;
  size: number;
  path: string;
}
