import type { ApiListData } from './api';

export type KnowledgeCollectionKind = 'favorites' | 'recent' | 'daily' | 'folder';

export type KnowledgeTreeNodeKind = 'folder' | 'document';

export type KnowledgeSystemFolderKey = 'daily';

export type KnowledgeDocumentKind = 'daily' | 'note';

export type KnowledgeSortKey = 'updated_desc' | 'title_asc';

export type KnowledgeSyncStatus =
  | 'synced'
  | 'pending_write'
  | 'unsynced'
  | 'external_modified'
  | 'local_missing'
  | 'sync_error'
  | 'readonly';

export type KnowledgeViewStatus =
  | 'ready'
  | 'empty'
  | 'missing_save_root'
  | 'readonly'
  | 'error';

export type KnowledgeResolveSyncAction = 'use_local' | 'keep_app' | 'dismiss';

export interface KnowledgePermissions {
  canView: boolean;
  canOpen: boolean;
  canCreateFolder: boolean;
  canCreateDocument: boolean;
  canRename: boolean;
  canDelete: boolean;
  canMove: boolean;
  canFavorite: boolean;
  canEdit: boolean;
  canSave: boolean;
  canSync: boolean;
  canResolveSync: boolean;
  reason?: string;
}

export interface KnowledgeStorageInfo {
  saveRootPath: string;
  hasSaveRoot: boolean;
  reason?: string;
}

export interface KnowledgeBreadcrumbItem {
  id: string;
  name: string;
  kind: 'collection' | 'folder' | 'document';
  collectionKind?: KnowledgeCollectionKind;
}

interface KnowledgeTreeNodeBase {
  id: string;
  name: string;
  kind: KnowledgeTreeNodeKind;
  parentId: string | null;
  depth: number;
  isSystem: boolean;
  relativePath: string;
  absolutePath: string;
  permissions: KnowledgePermissions;
}

export interface KnowledgeFolderTreeNode extends KnowledgeTreeNodeBase {
  kind: 'folder';
  systemKey?: KnowledgeSystemFolderKey;
  children: KnowledgeTreeNode[];
}

export interface KnowledgeDocumentTreeNode extends KnowledgeTreeNodeBase {
  kind: 'document';
  documentId: string;
  documentKind: KnowledgeDocumentKind;
  syncStatus: KnowledgeSyncStatus;
  isFavorite: boolean;
  children: [];
}

export type KnowledgeTreeNode = KnowledgeFolderTreeNode | KnowledgeDocumentTreeNode;

export interface KnowledgeTreeData {
  nodes: KnowledgeTreeNode[];
  status: KnowledgeViewStatus;
  permissions: KnowledgePermissions;
  storage: KnowledgeStorageInfo;
}

export interface KnowledgeScopeSummary {
  kind: KnowledgeCollectionKind;
  nodeId?: string | null;
  label: string;
  breadcrumbs: KnowledgeBreadcrumbItem[];
}

export interface KnowledgeDocumentSummary {
  id: string;
  title: string;
  fileName: string;
  kind: KnowledgeDocumentKind;
  date?: string;
  folderId: string | null;
  folderName: string;
  folderPath: string;
  createdAt: string;
  updatedAt: string;
  savedAt?: string;
  syncStatus: KnowledgeSyncStatus;
  syncLabel: string;
  syncHint?: string;
  isFavorite: boolean;
  excerpt: string;
  wordCount: number;
  relativePath: string;
  absolutePath: string;
  permissions: KnowledgePermissions;
}

export interface KnowledgeRecentHistoryItem {
  id: string;
  actor: string;
  action: string;
  timestamp: string;
  summary: string;
}

export interface KnowledgeDocumentDetail extends KnowledgeDocumentSummary {
  content: string;
  breadcrumbs: KnowledgeBreadcrumbItem[];
  history: KnowledgeRecentHistoryItem[];
  localChangedAt?: string;
  conflictSummary?: string;
}

export type KnowledgeDocumentListData =
  ApiListData<KnowledgeDocumentSummary, KnowledgePermissions> & {
    status: KnowledgeViewStatus;
    permissions: KnowledgePermissions;
    scope: KnowledgeScopeSummary;
  };

export interface KnowledgeMoveTargetsData {
  nodes: KnowledgeFolderTreeNode[];
  status: KnowledgeViewStatus;
  permissions: KnowledgePermissions;
}

export interface KnowledgeDocumentListQuery {
  scopeKind: KnowledgeCollectionKind;
  nodeId?: string | null;
  pageNo?: number;
  pageSize?: number;
  sort?: KnowledgeSortKey;
}

export interface CreateKnowledgeFolderPayload {
  parentId: string | null;
  name: string;
}

export interface CreateKnowledgeDocumentPayload {
  parentId: string | null;
  title: string;
}

export interface RenameKnowledgeItemPayload {
  itemType: 'folder' | 'document';
  id: string;
  name: string;
}

export interface MoveKnowledgeDocumentsPayload {
  documentIds: string[];
  targetFolderId: string;
}

export interface DeleteKnowledgeItemsPayload {
  itemType: 'folder' | 'document';
  itemIds: string[];
}

export interface ToggleKnowledgeFavoritePayload {
  documentId: string;
  value?: boolean;
}

export interface SaveKnowledgeDocumentPayload {
  documentId: string;
  title?: string;
  content: string;
}

export interface ResolveKnowledgeSyncPayload {
  documentId: string;
  action: KnowledgeResolveSyncAction;
}

/* ============================ 回收站 ============================ */

export interface TrashItem {
  id: string;
  itemType: 'folder' | 'document';
  name: string;
  kind: string;
  originalLocation: string;
  deletedAt: string;
}

export interface TrashListData {
  list: TrashItem[];
  total: number;
  pageNo: number;
  pageSize: number;
}

export interface RestoreTrashItemsPayload {
  itemType: 'folder' | 'document';
  itemIds: string[];
}

export interface PurgeTrashItemsPayload {
  itemType: 'folder' | 'document';
  itemIds: string[];
}

export interface TrashMutationResult {
  affected: number;
}
