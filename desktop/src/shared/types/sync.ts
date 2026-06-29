/** 多端内容同步相关类型，与后端 com.lifescale.backend.sync.dto 对齐。 */

export type SyncDocumentKind = 'daily' | 'note';

export interface SyncChangeSummary {
  id: string;
  kind: SyncDocumentKind;
  date?: string | null;
  updatedAt: string;
  contentHash?: string | null;
  status?: string;
}

export interface SyncChangesData {
  changes: SyncChangeSummary[];
  serverTime: string;
  hasMore: boolean;
}

export interface SyncDocumentData {
  id: string;
  kind: SyncDocumentKind;
  content: string;
  contentHash?: string | null;
  updatedAt: string;
}

export interface ConflictData {
  currentContent: string;
  currentHash?: string | null;
  currentUpdatedAt: string;
  yourContent: string;
}

export interface PushDocumentPayload {
  content: string;
  ifMatchHash?: string | null;
  sourceDevice?: string;
}

export interface HeartbeatPayload {
  deviceType?: string;
  lastSyncAt?: string;
}

export interface HeartbeatData {
  ack: boolean;
  serverTime: string;
}
