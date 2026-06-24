import dayjs from 'dayjs';
import type {
  CreateKnowledgeDocumentPayload,
  CreateKnowledgeFolderPayload,
  DeleteKnowledgeItemsPayload,
  KnowledgeBreadcrumbItem,
  KnowledgeCollectionKind,
  KnowledgeDocumentDetail,
  KnowledgeDocumentKind,
  KnowledgeDocumentListData,
  KnowledgeDocumentListQuery,
  KnowledgeDocumentSummary,
  KnowledgeFolderTreeNode,
  KnowledgeMoveTargetsData,
  KnowledgePermissions,
  KnowledgeScopeSummary,
  KnowledgeSortKey,
  KnowledgeStorageInfo,
  KnowledgeSyncStatus,
  KnowledgeTreeData,
  KnowledgeTreeNode,
  MoveKnowledgeDocumentsPayload,
  PurgeTrashItemsPayload,
  ResolveKnowledgeSyncPayload,
  RenameKnowledgeItemPayload,
  RestoreTrashItemsPayload,
  SaveKnowledgeDocumentPayload,
  ToggleKnowledgeFavoritePayload,
  TrashItem,
  TrashListData,
} from '../../shared/types/knowledgeBase';
import {
  generateDailyMarkdownDocument,
  getDailyMarkdownDocument,
  getMarkdownSettings,
  markDailyMarkdownSaved,
} from './dailyMarkdown';

const STORAGE_KEY = 'lifescale.mock.knowledge-base.v1';
const DAILY_ROOT_ID = 'knowledge-system-daily';
const DAILY_ROOT_NAME = 'Daily';

/** 记录状态：active 正常可见，deleted 已进入回收站（软删除）。 */
type RecordStatus = 'active' | 'deleted';

interface FolderRecord {
  id: string;
  name: string;
  parentId: string | null;
  isSystem: boolean;
  createdAt: string;
  updatedAt: string;
  /** 软删除状态，复用 status 字段，不单独建表。 */
  status?: RecordStatus;
  /** 进入回收站的时间，status 为 deleted 时有值。 */
  deletedAt?: string;
  /** 删除时记录的原位置路径，用于回收站展示与还原提示。 */
  deletedFromPath?: string;
}

interface DocumentHistoryRecord {
  id: string;
  actor: string;
  action: string;
  timestamp: string;
  summary: string;
}

interface DocumentRecord {
  id: string;
  title: string;
  kind: KnowledgeDocumentKind;
  folderId: string | null;
  date?: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  savedAt?: string;
  syncStatus: KnowledgeSyncStatus;
  isFavorite: boolean;
  localChangedAt?: string;
  externalContent?: string;
  conflictSummary?: string;
  history: DocumentHistoryRecord[];
  /** 软删除状态，复用 status 字段，不单独建表。 */
  status?: RecordStatus;
  /** 进入回收站的时间，status 为 deleted 时有值。 */
  deletedAt?: string;
  /** 删除时记录的原位置路径，用于回收站展示与还原提示。 */
  deletedFromPath?: string;
}

interface KnowledgeState {
  folders: FolderRecord[];
  documents: DocumentRecord[];
}

const SYSTEM_ACTOR = '林一';
const DEFAULT_EMPTY_CONTENT = '# 新建 Markdown\n\n开始整理这份文档吧。\n';
const VALID_SYNC_STATUSES = new Set<KnowledgeSyncStatus>([
  'synced',
  'pending_write',
  'unsynced',
  'external_modified',
  'local_missing',
  'sync_error',
  'readonly',
]);

const NOTE_DOCUMENTS: Array<
  Omit<DocumentRecord, 'content' | 'history'> & { content: string; history: DocumentHistoryRecord[] }
> = [
  {
    id: 'doc-requirements-outline',
    title: '需求梳理',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 需求梳理\n\n## 当前目标\n- 明确阶段八范围\n- 梳理知识库工作台的交互\n\n## 风险提醒\n- 不提前进入模板与搜索阶段\n',
    createdAt: '2026-06-13T09:20:00+08:00',
    updatedAt: '2026-06-16T10:23:00+08:00',
    savedAt: '2026-06-16T10:23:00+08:00',
    syncStatus: 'synced',
    isFavorite: true,
    history: [
      {
        id: 'history-requirements-1',
        actor: SYSTEM_ACTOR,
        action: '同步到本地',
        timestamp: '2026-06-16T10:23:00+08:00',
        summary: '已同步到工作 / 项目管理 / 需求梳理.md',
      },
    ],
  },
  {
    id: 'doc-information-architecture',
    title: '信息架构',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 信息架构\n\n## 主要模块\n- 文件夹树\n- 文档列表\n- 文档详情与编辑\n\n## 边界\n- 不包含模板和全文搜索\n',
    createdAt: '2026-06-13T12:05:00+08:00',
    updatedAt: '2026-06-16T09:41:00+08:00',
    savedAt: '2026-06-16T09:41:00+08:00',
    syncStatus: 'synced',
    isFavorite: false,
    history: [
      {
        id: 'history-information-1',
        actor: SYSTEM_ACTOR,
        action: '编辑文档',
        timestamp: '2026-06-16T09:41:00+08:00',
        summary: '补充了知识库三栏布局说明。',
      },
    ],
  },
  {
    id: 'doc-phase-eight-design',
    title: '阶段八设计草稿',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 阶段八：知识库与文件夹管理\n\n## 目标\n构建轻量知识库工作台，支持创建、整理、同步与编辑 Markdown 文档。\n\n## 关键能力\n- 文件夹树与文档列表\n- 收藏与最近编辑\n- 同步状态提示与风险确认\n',
    createdAt: '2026-06-10T11:20:00+08:00',
    updatedAt: '2026-06-15T18:36:00+08:00',
    syncStatus: 'pending_write',
    isFavorite: true,
    history: [
      {
        id: 'history-phase-eight-1',
        actor: SYSTEM_ACTOR,
        action: '编辑文档',
        timestamp: '2026-06-15T18:36:00+08:00',
        summary: '更新了同步状态与权限设计。',
      },
      {
        id: 'history-phase-eight-2',
        actor: SYSTEM_ACTOR,
        action: '创建文档',
        timestamp: '2026-06-10T11:20:00+08:00',
        summary: '在项目管理目录下创建了阶段八设计草稿。',
      },
    ],
  },
  {
    id: 'doc-desktop-interaction',
    title: '桌面端交互说明',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 桌面端交互说明\n\n## 本轮重点\n- 右键菜单\n- 行内重命名\n- 详情侧栏与独立编辑页\n',
    createdAt: '2026-06-12T15:40:00+08:00',
    updatedAt: '2026-06-15T16:12:00+08:00',
    savedAt: '2026-06-15T16:12:00+08:00',
    syncStatus: 'synced',
    isFavorite: false,
    history: [
      {
        id: 'history-desktop-1',
        actor: SYSTEM_ACTOR,
        action: '同步到本地',
        timestamp: '2026-06-15T16:12:00+08:00',
        summary: '本地文件已覆盖更新。',
      },
    ],
  },
  {
    id: 'doc-project-milestone',
    title: '项目里程碑计划',
    kind: 'note',
    folderId: 'folder-milestone-plan',
    content:
      '# 项目里程碑计划\n\n## 当前里程碑\n- 阶段六：每日 Markdown 沉淀\n- 阶段七：日历回看\n- 阶段八：知识库与文件夹管理\n',
    createdAt: '2026-06-12T20:10:00+08:00',
    updatedAt: '2026-06-14T21:05:00+08:00',
    savedAt: '2026-06-14T21:05:00+08:00',
    syncStatus: 'synced',
    isFavorite: true,
    history: [
      {
        id: 'history-milestone-1',
        actor: SYSTEM_ACTOR,
        action: '同步到本地',
        timestamp: '2026-06-14T21:05:00+08:00',
        summary: '里程碑计划已落盘。',
      },
    ],
  },
  {
    id: 'doc-risk-log',
    title: '风险与问题清单',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 风险与问题清单\n\n- 外部修改回写提示仍需 mock 演示\n- 编辑器依赖需要确认 React 19 兼容性\n',
    createdAt: '2026-06-13T11:00:00+08:00',
    updatedAt: '2026-06-13T17:48:00+08:00',
    savedAt: '2026-06-13T17:48:00+08:00',
    syncStatus: 'external_modified',
    isFavorite: false,
    localChangedAt: '2026-06-16T08:52:00+08:00',
    externalContent:
      '# 风险与问题清单\n\n- Obsidian 中补充了一条关于外部文件冲突处理的备注。\n- 需要在知识库页面展示明显的冲突横幅。\n',
    conflictSummary: '本地文件在 Obsidian 中被修改，应用内内容尚未合并。',
    history: [
      {
        id: 'history-risk-1',
        actor: SYSTEM_ACTOR,
        action: '检测到外部修改',
        timestamp: '2026-06-16T08:52:00+08:00',
        summary: '检测到 Vault 中同名文件已被其他工具改动。',
      },
    ],
  },
  {
    id: 'doc-weekly-meeting',
    title: '周会纪要',
    kind: 'note',
    folderId: 'folder-meeting-notes',
    content:
      '# 周会纪要\n\n## 本周结论\n- 阶段八以高保真前端为优先\n- 后端与数据库继续保持 mock 驱动边界\n',
    createdAt: '2026-06-13T09:30:00+08:00',
    updatedAt: '2026-06-13T10:30:00+08:00',
    syncStatus: 'pending_write',
    isFavorite: true,
    history: [
      {
        id: 'history-weekly-1',
        actor: SYSTEM_ACTOR,
        action: '编辑文档',
        timestamp: '2026-06-13T10:30:00+08:00',
        summary: '更新了本周阶段安排。',
      },
    ],
  },
  {
    id: 'doc-release-log',
    title: '版本发布记录',
    kind: 'note',
    folderId: 'folder-project-management',
    content:
      '# 版本发布记录\n\n- 2026-06-12：阶段七回看与日历能力完成\n- 2026-06-16：开始进入阶段八实现\n',
    createdAt: '2026-06-12T15:10:00+08:00',
    updatedAt: '2026-06-12T15:22:00+08:00',
    savedAt: '2026-06-12T15:22:00+08:00',
    syncStatus: 'local_missing',
    isFavorite: false,
    conflictSummary: '本地文件不存在，应用内快照仍可查看。',
    history: [
      {
        id: 'history-release-1',
        actor: SYSTEM_ACTOR,
        action: '本地文件缺失',
        timestamp: '2026-06-16T07:20:00+08:00',
        summary: '最近一次校验未在本地 Vault 中找到该文件。',
      },
    ],
  },
  {
    id: 'doc-product-principles',
    title: '产品设计原则',
    kind: 'note',
    folderId: 'folder-product-design',
    content:
      '# 产品设计原则\n\n- 轻量可控\n- 信息层级清晰\n- 以每日闭环为中心，不演变为复杂知识库\n',
    createdAt: '2026-06-11T14:00:00+08:00',
    updatedAt: '2026-06-14T13:40:00+08:00',
    savedAt: '2026-06-14T13:40:00+08:00',
    syncStatus: 'synced',
    isFavorite: false,
    history: [
      {
        id: 'history-principles-1',
        actor: SYSTEM_ACTOR,
        action: '同步到本地',
        timestamp: '2026-06-14T13:40:00+08:00',
        summary: '产品设计原则已保存到学习 / 产品设计。',
      },
    ],
  },
  {
    id: 'doc-ai-notes',
    title: 'AI 笔记整理',
    kind: 'note',
    folderId: 'folder-ai-notes',
    content:
      '# AI 笔记整理\n\n- 记录与知识沉淀要共享同一套 Markdown 资产\n- AI 能力放到 MVP 后续阶段再接入\n',
    createdAt: '2026-06-11T18:10:00+08:00',
    updatedAt: '2026-06-14T10:45:00+08:00',
    syncStatus: 'sync_error',
    isFavorite: false,
    conflictSummary: '上次写入本地失败，请重试同步。',
    history: [
      {
        id: 'history-ai-notes-1',
        actor: SYSTEM_ACTOR,
        action: '同步失败',
        timestamp: '2026-06-14T10:45:00+08:00',
        summary: '模拟写盘失败，等待用户重试。',
      },
    ],
  },
];

const DAILY_DOCUMENTS: DocumentRecord[] = [
  {
    id: 'daily-2026-06-15',
    title: '2026-06-15 每日记录',
    kind: 'daily',
    folderId: null,
    date: '2026-06-15',
    content: '',
    createdAt: '2026-06-15T08:00:00+08:00',
    updatedAt: '2026-06-15T18:36:00+08:00',
    syncStatus: 'synced',
    isFavorite: true,
    history: [
      {
        id: 'history-daily-0615-1',
        actor: SYSTEM_ACTOR,
        action: '每日文档生成',
        timestamp: '2026-06-15T18:36:00+08:00',
        summary: '复盘完成后已生成每日 Markdown。',
      },
    ],
  },
  {
    id: 'daily-2026-06-14',
    title: '2026-06-14 每日记录',
    kind: 'daily',
    folderId: null,
    date: '2026-06-14',
    content: '',
    createdAt: '2026-06-14T08:00:00+08:00',
    updatedAt: '2026-06-14T21:05:00+08:00',
    syncStatus: 'pending_write',
    isFavorite: false,
    history: [
      {
        id: 'history-daily-0614-1',
        actor: SYSTEM_ACTOR,
        action: '复盘保存',
        timestamp: '2026-06-14T21:05:00+08:00',
        summary: '应用内已更新，等待写入本地 Vault。',
      },
    ],
  },
  {
    id: 'daily-2026-06-13',
    title: '2026-06-13 每日记录',
    kind: 'daily',
    folderId: null,
    date: '2026-06-13',
    content: '',
    createdAt: '2026-06-13T08:00:00+08:00',
    updatedAt: '2026-06-13T20:40:00+08:00',
    syncStatus: 'external_modified',
    isFavorite: false,
    localChangedAt: '2026-06-16T09:10:00+08:00',
    conflictSummary: 'Daily/2026-06-13.md 已在本地被修改。',
    history: [
      {
        id: 'history-daily-0613-1',
        actor: SYSTEM_ACTOR,
        action: '检测到外部修改',
        timestamp: '2026-06-16T09:10:00+08:00',
        summary: '本地 Daily 文件与应用内快照不一致。',
      },
    ],
  },
];

function createInitialState(): KnowledgeState {
  for (const item of DAILY_DOCUMENTS) {
    if (item.date) {
      generateDailyMarkdownDocument(item.date);
    }
  }

  return {
    folders: [
      {
        id: 'folder-work',
        name: '工作',
        parentId: null,
        isSystem: true,
        createdAt: '2026-06-10T08:00:00+08:00',
        updatedAt: '2026-06-16T10:23:00+08:00',
      },
      {
        id: 'folder-project-management',
        name: '项目管理',
        parentId: 'folder-work',
        isSystem: true,
        createdAt: '2026-06-10T08:10:00+08:00',
        updatedAt: '2026-06-16T10:23:00+08:00',
      },
      {
        id: 'folder-requirements-pool',
        name: '需求池',
        parentId: 'folder-project-management',
        isSystem: false,
        createdAt: '2026-06-10T08:12:00+08:00',
        updatedAt: '2026-06-10T08:12:00+08:00',
      },
      {
        id: 'folder-milestone-plan',
        name: '里程碑计划',
        parentId: 'folder-project-management',
        isSystem: false,
        createdAt: '2026-06-10T08:15:00+08:00',
        updatedAt: '2026-06-14T21:05:00+08:00',
      },
      {
        id: 'folder-meeting-notes',
        name: '会议记录',
        parentId: 'folder-work',
        isSystem: true,
        createdAt: '2026-06-10T08:20:00+08:00',
        updatedAt: '2026-06-13T10:30:00+08:00',
      },
      {
        id: 'folder-life',
        name: '生活',
        parentId: null,
        isSystem: true,
        createdAt: '2026-06-10T08:30:00+08:00',
        updatedAt: '2026-06-10T08:30:00+08:00',
      },
      {
        id: 'folder-study',
        name: '学习',
        parentId: null,
        isSystem: true,
        createdAt: '2026-06-10T08:40:00+08:00',
        updatedAt: '2026-06-14T13:40:00+08:00',
      },
      {
        id: 'folder-product-design',
        name: '产品设计',
        parentId: 'folder-study',
        isSystem: true,
        createdAt: '2026-06-10T08:45:00+08:00',
        updatedAt: '2026-06-14T13:40:00+08:00',
      },
      {
        id: 'folder-ai-notes',
        name: 'AI 笔记',
        parentId: 'folder-study',
        isSystem: true,
        createdAt: '2026-06-10T08:50:00+08:00',
        updatedAt: '2026-06-14T10:45:00+08:00',
      },
    ],
    documents: [
      ...NOTE_DOCUMENTS.map((item) => ({ ...item })),
      ...DAILY_DOCUMENTS.map((item) => ({ ...item })),
    ],
  };
}

function normalizeState(nextState: KnowledgeState): KnowledgeState {
  const removedFolderIds = new Set(
    nextState.folders
      .filter((folder) => 'isRestricted' in folder && Boolean((folder as FolderRecord & { isRestricted?: boolean }).isRestricted))
      .map((folder) => folder.id),
  );

  return {
    folders: nextState.folders.filter(
      (folder) => !('isRestricted' in folder && Boolean((folder as FolderRecord & { isRestricted?: boolean }).isRestricted)),
    ),
    documents: nextState.documents.filter((document) => {
      const legacyDocument = document as DocumentRecord & { isRestricted?: boolean };
      const legacySyncStatus = (document as { syncStatus?: string }).syncStatus;
      if (legacyDocument.isRestricted) {
        return false;
      }
      if (!legacySyncStatus || !VALID_SYNC_STATUSES.has(legacySyncStatus as KnowledgeSyncStatus)) {
        return false;
      }
      if (document.folderId && removedFolderIds.has(document.folderId)) {
        return false;
      }
      return true;
    }),
  };
}

function loadState(): KnowledgeState {
  const fallback = normalizeState(createInitialState());
  if (typeof window === 'undefined') {
    return fallback;
  }

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return fallback;
    }
    const parsed = JSON.parse(raw) as Partial<KnowledgeState>;
    return normalizeState({
      folders: parsed.folders ?? fallback.folders,
      documents: parsed.documents ?? fallback.documents,
    });
  } catch {
    return fallback;
  }
}

let state = loadState();

function persist(): void {
  if (typeof window === 'undefined') {
    return;
  }
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Best effort only for mock mode.
  }
}

function getNow(): string {
  return new Date().toISOString();
}

function buildId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function sanitizeName(name: string): string {
  return name.trim().replace(/[\\/]+/g, ' ').replace(/\s+/g, ' ');
}

function normalizeFileName(title: string): string {
  const clean = sanitizeName(title).replace(/[<>:"|?*]/g, '-');
  const withoutExtension = clean.replace(/\.md$/i, '');
  return `${withoutExtension || '未命名文档'}.md`;
}

function joinPath(rootPath: string, relativePath: string): string {
  if (!rootPath.trim()) {
    return relativePath;
  }
  const cleanRoot = rootPath.trim().replace(/[\\/]+$/, '');
  const separator = cleanRoot.includes('\\') ? '\\' : '/';
  return `${cleanRoot}${separator}${relativePath.replace(/\//g, separator)}`;
}

function findFolder(folderId: string | null): FolderRecord | undefined {
  return folderId ? state.folders.find((folder) => folder.id === folderId) : undefined;
}

function listChildFolders(parentId: string | null): FolderRecord[] {
  return state.folders.filter(
    (folder) => folder.parentId === parentId && folder.status !== 'deleted',
  );
}

function collectDescendantFolderIds(folderId: string): string[] {
  const childIds = listChildFolders(folderId).map((child) => child.id);
  return childIds.flatMap((childId) => [childId, ...collectDescendantFolderIds(childId)]);
}

function getFolderAncestors(folderId: string | null): FolderRecord[] {
  const folders: FolderRecord[] = [];
  let current = findFolder(folderId);
  while (current) {
    folders.unshift(current);
    current = findFolder(current.parentId);
  }
  return folders;
}

function getFolderPathSegments(folderId: string | null): string[] {
  return getFolderAncestors(folderId).map((folder) => folder.name);
}

function getFolderRelativePath(folderId: string | null): string {
  return getFolderPathSegments(folderId).join('/');
}

function getStorageInfo(): KnowledgeStorageInfo {
  const settings = getMarkdownSettings();
  return {
    saveRootPath: settings.saveRootPath,
    hasSaveRoot: Boolean(settings.saveRootPath),
    reason: settings.permissions.reason,
  };
}

function basePermissions(hasSaveRoot: boolean): KnowledgePermissions {
  return {
    canView: true,
    canOpen: true,
    canCreateFolder: hasSaveRoot,
    canCreateDocument: hasSaveRoot,
    canRename: true,
    canDelete: true,
    canMove: true,
    canFavorite: true,
    canEdit: hasSaveRoot,
    canSave: hasSaveRoot,
    canSync: hasSaveRoot,
    canResolveSync: true,
    reason: hasSaveRoot ? undefined : '请先在空间设置中选择 Markdown 保存根目录',
  };
}

function readonlyPermissions(reason: string): KnowledgePermissions {
  return {
    ...basePermissions(true),
    canEdit: false,
    canSave: false,
    canSync: false,
    reason,
  };
}

function getFolderPermissions(_folder: FolderRecord, hasSaveRoot: boolean): KnowledgePermissions {
  return basePermissions(hasSaveRoot);
}

function getDocumentPermissions(
  document: DocumentRecord,
  hasSaveRoot: boolean,
): KnowledgePermissions {
  if (document.kind === 'daily') {
    const base = hasSaveRoot
      ? basePermissions(true)
      : {
          ...basePermissions(false),
          canCreateDocument: false,
          canCreateFolder: false,
        };

    if (document.syncStatus === 'readonly') {
      return readonlyPermissions('当前每日文档处于只读状态');
    }

    return {
      ...base,
      canRename: false,
      canDelete: false,
      canMove: false,
    };
  }

  return {
    ...basePermissions(hasSaveRoot),
    canEdit: true,
    canSave: true,
    reason: hasSaveRoot
      ? undefined
      : '可先在应用内编辑；同步到本地前请设置 Markdown 保存根目录',
  };
}

function getSyncLabel(status: KnowledgeSyncStatus): string {
  switch (status) {
    case 'synced':
      return '已同步';
    case 'pending_write':
      return '待写入';
    case 'unsynced':
      return '未同步';
    case 'external_modified':
      return '本地已变更';
    case 'local_missing':
      return '本地缺失';
    case 'sync_error':
      return '同步失败';
    case 'readonly':
      return '只读';
    default:
      return '未同步';
  }
}

function getSyncHint(status: KnowledgeSyncStatus): string | undefined {
  switch (status) {
    case 'pending_write':
      return '应用内最新内容尚未写入本地 Markdown 文件。';
    case 'unsynced':
      return '当前内容仍停留在应用内，请手动同步到本地。';
    case 'external_modified':
      return '本地 Markdown 已被外部工具修改，需要决定采用哪一份内容。';
    case 'local_missing':
      return '找不到对应的本地文件，可重新同步生成。';
    case 'sync_error':
      return '上次写入本地失败，请稍后重试。';
    case 'readonly':
      return '当前文档只读，可查看但不可修改。';
    default:
      return undefined;
  }
}

function countWords(content: string): number {
  return content.replace(/\s+/g, '').length;
}

function getExcerpt(content: string): string {
  const clean = content
    .split('\n')
    .map((line) => line.trim())
    .find((line) => line.length > 0 && !line.startsWith('#'));

  return clean ?? '暂无内容摘要';
}

function getNoteRelativePath(document: DocumentRecord): string {
  const folderPath = getFolderRelativePath(document.folderId);
  const fileName = normalizeFileName(document.title);
  return folderPath ? `${folderPath}/${fileName}` : fileName;
}

function getDailyRelativePath(date: string): string {
  return `Daily/${date}.md`;
}

function getDailySourceDocument(date: string) {
  const existing = getDailyMarkdownDocument(date);
  return existing.content.trim() ? existing : generateDailyMarkdownDocument(date);
}

function hydrateDocument(document: DocumentRecord): KnowledgeDocumentSummary {
  const storage = getStorageInfo();
  const hasSaveRoot = storage.hasSaveRoot;
  const folderPathSegments = document.kind === 'daily' ? ['Daily'] : getFolderPathSegments(document.folderId);
  const folderPath = folderPathSegments.join(' / ');
  const folderName = folderPathSegments[folderPathSegments.length - 1] ?? '根目录';
  const fileName = document.kind === 'daily'
    ? `${document.date}.md`
    : normalizeFileName(document.title);
  const sourceDocument =
    document.kind === 'daily' && document.date ? getDailySourceDocument(document.date) : null;
  const relativePath =
    document.kind === 'daily' && document.date
      ? getDailyRelativePath(document.date)
      : getNoteRelativePath(document);
  const absolutePath = joinPath(storage.saveRootPath, relativePath);
  const content = sourceDocument?.content ?? document.content;
  const savedAt = sourceDocument?.savedAt ?? document.savedAt;
  const permissions = getDocumentPermissions(document, hasSaveRoot);
  const syncStatus = document.syncStatus;

  return {
    id: document.id,
    title: document.title,
    fileName,
    kind: document.kind,
    date: document.date,
    folderId: document.folderId,
    folderName,
    folderPath,
    createdAt: document.createdAt,
    updatedAt: sourceDocument?.updatedAt ?? document.updatedAt,
    savedAt,
    syncStatus,
    syncLabel: getSyncLabel(syncStatus),
    syncHint: document.conflictSummary ?? getSyncHint(syncStatus),
    isFavorite: document.isFavorite,
    excerpt: getExcerpt(content),
    wordCount: countWords(content),
    relativePath,
    absolutePath,
    permissions,
  };
}

function sortByName<T extends { name: string }>(items: T[]): T[] {
  return items.slice().sort((left, right) => left.name.localeCompare(right.name, 'zh-CN'));
}

function sortDocumentRecordsByTitle(items: DocumentRecord[]): DocumentRecord[] {
  return items.slice().sort((left, right) => left.title.localeCompare(right.title, 'zh-CN'));
}

function isDailyRootId(nodeId: string | null | undefined): boolean {
  return nodeId === DAILY_ROOT_ID;
}

function listFolderDocuments(folderId: string | null): DocumentRecord[] {
  return state.documents.filter(
    (document) =>
      document.kind === 'note' &&
      document.folderId === folderId &&
      document.status !== 'deleted',
  );
}

function getDailyFolderPermissions(hasSaveRoot: boolean): KnowledgePermissions {
  return {
    ...basePermissions(hasSaveRoot),
    canCreateFolder: false,
    canCreateDocument: false,
    canRename: false,
    canDelete: false,
    canMove: false,
    canEdit: false,
    canSave: false,
    canSync: false,
    reason: 'Daily 目录用于承载每日文档，不支持结构调整。',
  };
}

function buildDocumentTreeNode(
  document: DocumentRecord,
  depth: number,
  parentId: string | null,
): KnowledgeTreeNode {
  const summary = hydrateDocument(document);
  return {
    id: document.id,
    name: summary.title,
    kind: 'document',
    documentId: document.id,
    documentKind: document.kind,
    syncStatus: summary.syncStatus,
    isFavorite: summary.isFavorite,
    parentId,
    depth,
    isSystem: document.kind === 'daily',
    relativePath: summary.relativePath,
    absolutePath: summary.absolutePath,
    children: [],
    permissions: summary.permissions,
  };
}

function buildFolderChildren(folderId: string, depth: number): KnowledgeTreeNode[] {
  const folders = sortByName(listChildFolders(folderId)).map((child) => buildFolderNode(child, depth));
  const documents = sortDocumentRecordsByTitle(listFolderDocuments(folderId)).map((document) =>
    buildDocumentTreeNode(document, depth, folderId),
  );
  return [...folders, ...documents];
}

function buildFolderNode(folder: FolderRecord, depth: number): KnowledgeFolderTreeNode {
  const storage = getStorageInfo();
  const relativePath = getFolderRelativePath(folder.id);

  return {
    id: folder.id,
    name: folder.name,
    kind: 'folder',
    parentId: folder.parentId,
    depth,
    isSystem: folder.isSystem,
    relativePath,
    absolutePath: joinPath(storage.saveRootPath, relativePath),
    children: buildFolderChildren(folder.id, depth + 1),
    permissions: getFolderPermissions(folder, storage.hasSaveRoot),
  };
}

function buildDailyFolderNode(): KnowledgeFolderTreeNode {
  const storage = getStorageInfo();
  const children = sortDocumentRecordsByTitle(
    state.documents.filter((document) => document.kind === 'daily' && document.status !== 'deleted'),
  ).map((document) => buildDocumentTreeNode(document, 1, DAILY_ROOT_ID));

  return {
    id: DAILY_ROOT_ID,
    name: DAILY_ROOT_NAME,
    kind: 'folder',
    parentId: null,
    depth: 0,
    isSystem: true,
    systemKey: 'daily',
    relativePath: DAILY_ROOT_NAME,
    absolutePath: joinPath(storage.saveRootPath, DAILY_ROOT_NAME),
    children,
    permissions: getDailyFolderPermissions(storage.hasSaveRoot),
  };
}

function buildTreeNodes(): KnowledgeTreeNode[] {
  const rootFolders = sortByName(listChildFolders(null)).map((folder) => buildFolderNode(folder, 0));
  const rootDocuments = sortDocumentRecordsByTitle(listFolderDocuments(null)).map((document) =>
    buildDocumentTreeNode(document, 0, null),
  );
  return sortByName<KnowledgeTreeNode>([buildDailyFolderNode(), ...rootFolders, ...rootDocuments]).sort(
    (left, right) => {
      if (left.kind === right.kind) {
        return left.name.localeCompare(right.name, 'zh-CN');
      }
      return left.kind === 'folder' ? -1 : 1;
    },
  );
}

function buildScopeSummary(kind: KnowledgeCollectionKind, nodeId?: string | null): KnowledgeScopeSummary {
  if (kind === 'favorites') {
    return {
      kind,
      label: '收藏',
      breadcrumbs: [{ id: 'collection-favorites', name: '收藏', kind: 'collection', collectionKind: kind }],
    };
  }

  if (kind === 'recent') {
    return {
      kind,
      label: '最近编辑',
      breadcrumbs: [{ id: 'collection-recent', name: '最近编辑', kind: 'collection', collectionKind: kind }],
    };
  }

  if (kind === 'daily') {
    return {
      kind,
      label: '每日记录',
      breadcrumbs: [{ id: 'collection-daily', name: '每日记录', kind: 'collection', collectionKind: kind }],
    };
  }

  if (isDailyRootId(nodeId)) {
    return {
      kind: 'folder',
      nodeId: DAILY_ROOT_ID,
      label: DAILY_ROOT_NAME,
      breadcrumbs: [
        { id: 'collection-folder', name: '知识库', kind: 'collection', collectionKind: 'folder' },
        { id: DAILY_ROOT_ID, name: DAILY_ROOT_NAME, kind: 'folder' },
      ],
    };
  }

  const folder = findFolder(nodeId ?? null);
  const breadcrumbs: KnowledgeBreadcrumbItem[] = [
    { id: 'collection-folder', name: '知识库', kind: 'collection', collectionKind: 'folder' },
    ...getFolderAncestors(folder?.id ?? null).map((item) => ({
      id: item.id,
      name: item.name,
      kind: 'folder' as const,
    })),
  ];

  return {
    kind: 'folder',
    nodeId: folder?.id ?? null,
    label: folder?.name ?? '根目录',
    breadcrumbs,
  };
}

function sortDocuments(
  documents: KnowledgeDocumentSummary[],
  sort: KnowledgeSortKey,
): KnowledgeDocumentSummary[] {
  if (sort === 'title_asc') {
    return documents.slice().sort((left, right) => left.title.localeCompare(right.title, 'zh-CN'));
  }

  return documents
    .slice()
    .sort((left, right) => dayjs(right.updatedAt).valueOf() - dayjs(left.updatedAt).valueOf());
}

function filterDocuments(query: KnowledgeDocumentListQuery): KnowledgeDocumentSummary[] {
  const summaries = state.documents
    .filter((document) => document.status !== 'deleted')
    .map((document) => hydrateDocument(document));

  if (query.scopeKind === 'favorites') {
    return summaries.filter((document) => document.isFavorite);
  }

  if (query.scopeKind === 'recent') {
    return summaries;
  }

  if (query.scopeKind === 'daily') {
    return summaries.filter((document) => document.kind === 'daily');
  }

  if (isDailyRootId(query.nodeId)) {
    return summaries.filter((document) => document.kind === 'daily');
  }

  if (!query.nodeId) {
    return summaries.filter((document) => document.kind === 'note' && document.folderId === null);
  }

  const scopedFolderIds = new Set([query.nodeId, ...collectDescendantFolderIds(query.nodeId)]);
  return summaries.filter(
    (document) =>
      document.kind === 'note' &&
      Boolean(document.folderId) &&
      scopedFolderIds.has(document.folderId as string),
  );
}

function findDocumentRecord(documentId: string): DocumentRecord | undefined {
  return state.documents.find((document) => document.id === documentId);
}

function addHistory(
  documentId: string,
  action: string,
  summary: string,
  timestamp = getNow(),
): void {
  const document = findDocumentRecord(documentId);
  if (!document) {
    return;
  }
  document.history.unshift({
    id: buildId('history'),
    actor: SYSTEM_ACTOR,
    action,
    timestamp,
    summary,
  });
}

function touchDocument(document: DocumentRecord, patch: Partial<DocumentRecord>): void {
  Object.assign(document, patch);
}

export function getKnowledgeTree(): KnowledgeTreeData {
  const storage = getStorageInfo();
  const nodes = buildTreeNodes();

  return {
    nodes,
    status: nodes.length ? 'ready' : 'empty',
    permissions: basePermissions(storage.hasSaveRoot),
    storage,
  };
}

export function listKnowledgeDocuments(
  query: KnowledgeDocumentListQuery,
): KnowledgeDocumentListData {
  const storage = getStorageInfo();
  const scope = buildScopeSummary(query.scopeKind, query.nodeId);

  const list = sortDocuments(filterDocuments(query), query.sort ?? 'updated_desc');
  const pageNo = query.pageNo ?? 1;
  const pageSize = query.pageSize ?? 50;
  const start = (pageNo - 1) * pageSize;

  return {
    list: list.slice(start, start + pageSize),
    total: list.length,
    pageNo,
    pageSize,
    status: list.length ? 'ready' : 'empty',
    permissions: basePermissions(storage.hasSaveRoot),
    scope,
  };
}

export function getKnowledgeDocumentDetail(
  documentId: string,
): KnowledgeDocumentDetail | null {
  const document = findDocumentRecord(documentId);
  if (!document) {
    return null;
  }

  const summary = hydrateDocument(document);
  const sourceDaily =
    document.kind === 'daily' && document.date ? getDailySourceDocument(document.date) : null;
  const folderAncestors = document.kind === 'daily' ? [] : getFolderAncestors(document.folderId);
  const breadcrumbs: KnowledgeBreadcrumbItem[] =
    document.kind === 'daily'
      ? [
          { id: 'collection-folder', name: '知识库', kind: 'collection', collectionKind: 'folder' },
          { id: DAILY_ROOT_ID, name: DAILY_ROOT_NAME, kind: 'folder' },
          { id: document.id, name: summary.title, kind: 'document' },
        ]
      : [
          { id: 'collection-folder', name: '知识库', kind: 'collection', collectionKind: 'folder' },
          ...folderAncestors.map((folder) => ({
            id: folder.id,
            name: folder.name,
            kind: 'folder' as const,
          })),
          { id: document.id, name: summary.title, kind: 'document' },
        ];

  return {
    ...summary,
    content: sourceDaily?.content ?? document.content,
    breadcrumbs,
    history: document.history.map((item) => ({ ...item })),
    localChangedAt: document.localChangedAt,
    conflictSummary: document.conflictSummary,
  };
}

export function getKnowledgeMoveTargets(): KnowledgeMoveTargetsData {
  const tree = getKnowledgeTree();
  const cloneVisibleNodes = (nodes: KnowledgeTreeNode[]): KnowledgeFolderTreeNode[] =>
    nodes
      .filter(
        (node): node is KnowledgeFolderTreeNode =>
          node.kind === 'folder' &&
          node.permissions.canView &&
          node.systemKey !== 'daily',
      )
      .map((node) => ({
        ...node,
        children: cloneVisibleNodes(node.children),
      }));

  return {
    nodes: cloneVisibleNodes(tree.nodes),
    status: tree.status,
    permissions: tree.permissions,
  };
}

export function createKnowledgeFolder(
  payload: CreateKnowledgeFolderPayload,
): KnowledgeFolderTreeNode | null {
  const storage = getStorageInfo();
  if (!storage.hasSaveRoot || isDailyRootId(payload.parentId)) {
    return null;
  }

  const cleanName = sanitizeName(payload.name);
  if (!cleanName) {
    return null;
  }

  const now = getNow();
  const folder: FolderRecord = {
    id: buildId('folder'),
    name: cleanName,
    parentId: payload.parentId,
    isSystem: false,
    createdAt: now,
    updatedAt: now,
  };
  state = {
    ...state,
    folders: [...state.folders, folder],
  };
  persist();
  return buildFolderNode(folder, payload.parentId ? getFolderAncestors(payload.parentId).length : 0);
}

export function createKnowledgeDocument(
  payload: CreateKnowledgeDocumentPayload,
): KnowledgeDocumentSummary | null {
  const storage = getStorageInfo();
  if (!storage.hasSaveRoot || isDailyRootId(payload.parentId)) {
    return null;
  }

  const cleanTitle = sanitizeName(payload.title);
  if (!cleanTitle) {
    return null;
  }

  const now = getNow();
  const document: DocumentRecord = {
    id: buildId('doc'),
    title: cleanTitle,
    kind: 'note',
    folderId: payload.parentId,
    content: DEFAULT_EMPTY_CONTENT.replace('新建 Markdown', cleanTitle),
    createdAt: now,
    updatedAt: now,
    syncStatus: 'pending_write',
    isFavorite: false,
    history: [],
  };
  state = {
    ...state,
    documents: [document, ...state.documents],
  };
  addHistory(document.id, '创建文档', `在 ${getFolderRelativePath(payload.parentId) || '根目录'} 下创建文档`);
  persist();
  return hydrateDocument(document);
}

export function renameKnowledgeItem(
  payload: RenameKnowledgeItemPayload,
): KnowledgeDocumentSummary | KnowledgeTreeNode | null {
  const cleanName = sanitizeName(payload.name);
  if (!cleanName) {
    return null;
  }

  if (payload.itemType === 'folder') {
    if (isDailyRootId(payload.id)) {
      return null;
    }
    const folder = findFolder(payload.id);
    if (!folder) {
      return null;
    }
    folder.name = cleanName;
    folder.updatedAt = getNow();
    persist();
    return buildFolderNode(folder, getFolderAncestors(folder.parentId).length);
  }

  const document = findDocumentRecord(payload.id);
  if (!document || document.kind === 'daily') {
    return null;
  }
  const now = getNow();
  touchDocument(document, {
    title: cleanName,
    updatedAt: now,
    syncStatus: getStorageInfo().hasSaveRoot ? 'pending_write' : 'unsynced',
  });
  addHistory(document.id, '重命名文档', `重命名为 ${cleanName}`, now);
  persist();
  return hydrateDocument(document);
}

export function moveKnowledgeDocuments(
  payload: MoveKnowledgeDocumentsPayload,
): KnowledgeDocumentSummary[] {
  const targetFolder = findFolder(payload.targetFolderId);
  if (!targetFolder) {
    return [];
  }

  const now = getNow();
  const moved: KnowledgeDocumentSummary[] = [];
  for (const documentId of payload.documentIds) {
    const document = findDocumentRecord(documentId);
    if (!document || document.kind === 'daily') {
      continue;
    }
    touchDocument(document, {
      folderId: payload.targetFolderId,
      updatedAt: now,
      syncStatus: getStorageInfo().hasSaveRoot ? 'pending_write' : 'unsynced',
    });
    addHistory(document.id, '移动文档', `已移动到 ${getFolderRelativePath(payload.targetFolderId)}`, now);
    moved.push(hydrateDocument(document));
  }
  persist();
  return moved;
}

export function deleteKnowledgeItems(payload: DeleteKnowledgeItemsPayload): boolean {
  const now = getNow();

  if (payload.itemType === 'folder') {
    const ids = new Set<string>();
    for (const itemId of payload.itemIds) {
      const folder = findFolder(itemId);
      if (!folder) {
        continue;
      }
      ids.add(itemId);
      for (const childId of collectDescendantFolderIds(itemId)) {
        ids.add(childId);
      }
    }
    if (ids.size === 0) {
      return false;
    }
    // 软删除：把命中的文件夹及其子孙标记为 deleted，并记录删除时原位置路径。
    state = {
      ...state,
      folders: state.folders.map((folder) => {
        if (!ids.has(folder.id) || folder.status === 'deleted') {
          return folder;
        }
        return {
          ...folder,
          status: 'deleted',
          deletedAt: now,
          deletedFromPath: getFolderRelativePath(folder.id) || '根目录',
        };
      }),
      // 文件夹软删除时，其下文档（含子孙文件夹下的文档）一并软删除，便于还原时整体找回。
      documents: state.documents.map((document) => {
        if (
          document.status === 'deleted' ||
          document.kind === 'daily' ||
          !document.folderId ||
          !ids.has(document.folderId)
        ) {
          return document;
        }
        return {
          ...document,
          status: 'deleted',
          deletedAt: now,
          deletedFromPath: getNoteRelativePath(document),
        };
      }),
    };
    persist();
    return true;
  }

  const deletable = new Set(
    payload.itemIds.filter((itemId) => {
      const document = findDocumentRecord(itemId);
      return Boolean(document && document.kind !== 'daily');
    }),
  );
  if (deletable.size === 0) {
    return false;
  }
  // 软删除：文档进入回收站，不物理消失，可在回收站还原或彻底删除。
  state = {
    ...state,
    documents: state.documents.map((document) => {
      if (!deletable.has(document.id) || document.status === 'deleted') {
        return document;
      }
      return {
        ...document,
        status: 'deleted',
        deletedAt: now,
        deletedFromPath: getNoteRelativePath(document),
      };
    }),
  };
  persist();
  return true;
}

export function toggleKnowledgeFavorite(
  payload: ToggleKnowledgeFavoritePayload,
): KnowledgeDocumentSummary | null {
  const document = findDocumentRecord(payload.documentId);
  if (!document) {
    return null;
  }
  const nextValue = payload.value ?? !document.isFavorite;
  document.isFavorite = nextValue;
  document.updatedAt = getNow();
  addHistory(
    document.id,
    nextValue ? '加入收藏' : '取消收藏',
    nextValue ? '已加入常用内容。' : '已从常用内容中移除。',
    document.updatedAt,
  );
  persist();
  return hydrateDocument(document);
}

export function saveKnowledgeDocument(
  payload: SaveKnowledgeDocumentPayload,
): KnowledgeDocumentDetail | null {
  const document = findDocumentRecord(payload.documentId);
  if (!document || document.kind === 'daily') {
    return null;
  }
  const now = getNow();
  const nextTitle = payload.title ? sanitizeName(payload.title) : document.title;
  touchDocument(document, {
    title: nextTitle || document.title,
    content: payload.content,
    updatedAt: now,
    syncStatus: getStorageInfo().hasSaveRoot ? 'pending_write' : 'unsynced',
  });
  addHistory(document.id, '保存文档', '应用内草稿已更新，等待写入本地。', now);
  persist();
  return getKnowledgeDocumentDetail(document.id);
}

export function markKnowledgeDocumentSynced(
  documentId: string,
): KnowledgeDocumentDetail | null {
  const document = findDocumentRecord(documentId);
  if (!document) {
    return null;
  }
  const now = getNow();
  if (document.kind === 'daily' && document.date) {
    const daily = markDailyMarkdownSaved(document.date);
    touchDocument(document, {
      updatedAt: daily.updatedAt,
      savedAt: daily.savedAt,
      syncStatus: 'synced',
      conflictSummary: undefined,
      localChangedAt: undefined,
    });
    addHistory(document.id, '同步到本地', `已写入 ${daily.relativePath}`, now);
    persist();
    return getKnowledgeDocumentDetail(document.id);
  }

  touchDocument(document, {
    updatedAt: now,
    savedAt: now,
    syncStatus: 'synced',
    conflictSummary: undefined,
    localChangedAt: undefined,
  });
  addHistory(document.id, '同步到本地', '应用内内容已覆盖写入本地 Markdown 文件。', now);
  persist();
  return getKnowledgeDocumentDetail(document.id);
}

export function resolveKnowledgeSync(
  payload: ResolveKnowledgeSyncPayload,
): KnowledgeDocumentDetail | null {
  const document = findDocumentRecord(payload.documentId);
  if (!document) {
    return null;
  }

  const now = getNow();
  if (payload.action === 'use_local') {
    touchDocument(document, {
      content: document.externalContent ?? document.content,
      updatedAt: now,
      savedAt: now,
      syncStatus: 'synced',
      conflictSummary: undefined,
      localChangedAt: undefined,
    });
    addHistory(document.id, '采用本地版本', '应用内内容已切换为本地 Markdown 版本。', now);
  } else if (payload.action === 'keep_app') {
    touchDocument(document, {
      updatedAt: now,
      syncStatus: getStorageInfo().hasSaveRoot ? 'pending_write' : 'unsynced',
      conflictSummary: undefined,
      localChangedAt: undefined,
    });
    addHistory(document.id, '保留应用内版本', '已保留应用内内容，请重新同步到本地。', now);
  } else {
    touchDocument(document, {
      updatedAt: now,
      syncStatus: getStorageInfo().hasSaveRoot ? 'unsynced' : 'unsynced',
      conflictSummary: undefined,
      localChangedAt: undefined,
    });
    addHistory(document.id, '稍后处理', '已暂时关闭同步冲突提示。', now);
  }

  persist();
  return getKnowledgeDocumentDetail(document.id);
}

/* ============================ 回收站 ============================ */

/** 判断某个文件夹的祖先链上是否仍存在 active 状态的文件夹（用于还原时判断是否需回根目录）。 */
function hasActiveAncestor(folderId: string | null): boolean {
  let current = findFolder(folderId);
  while (current) {
    if (current.status === 'deleted') {
      return false;
    }
    current = findFolder(current.parentId);
  }
  return true;
}

/** 把记录映射为回收站展示项。 */
function toTrashItem(
  record: { id: string; deletedAt?: string; deletedFromPath?: string },
  itemType: 'folder' | 'document',
  name: string,
  kind: string,
): TrashItem {
  return {
    id: record.id,
    itemType,
    name,
    kind,
    originalLocation: record.deletedFromPath || '根目录',
    deletedAt: record.deletedAt || getNow(),
  };
}

export function getTrashList(pageNo = 1, pageSize = 50): TrashListData {
  const folderItems: TrashItem[] = state.folders
    .filter((folder) => folder.status === 'deleted')
    .map((folder) =>
      toTrashItem(folder, 'folder', folder.name, folder.isSystem ? '系统文件夹' : '文件夹'),
    );
  const documentItems: TrashItem[] = state.documents
    .filter((document) => document.status === 'deleted')
    .map((document) =>
      toTrashItem(
        document,
        'document',
        document.title,
        document.kind === 'daily' ? '每日文档' : 'Markdown 文档',
      ),
    );

  // 合并后按删除时间倒序展示。
  const list = [...folderItems, ...documentItems].sort((left, right) =>
    dayjs(right.deletedAt).valueOf() - dayjs(left.deletedAt).valueOf(),
  );

  const start = (pageNo - 1) * pageSize;
  return {
    list: list.slice(start, start + pageSize),
    total: list.length,
    pageNo,
    pageSize,
  };
}

export function restoreTrashItems(payload: RestoreTrashItemsPayload): number {
  const ids = new Set(payload.itemIds);
  const now = getNow();
  let affected = 0;

  if (payload.itemType === 'folder') {
    const restoreFolderTree = (rootId: string) => {
      const folder = findFolder(rootId);
      if (!folder || folder.status !== 'deleted') {
        return;
      }
      // 还原时若父项仍处于删除态，回到根目录，避免悬挂引用。
      const parentStillDeleted =
        folder.parentId !== null &&
        (findFolder(folder.parentId)?.status === 'deleted' || !hasActiveAncestor(folder.parentId));
      const nextParentId = parentStillDeleted ? null : folder.parentId;
      folder.parentId = nextParentId;
      folder.status = 'active';
      folder.updatedAt = now;
      delete folder.deletedAt;
      delete folder.deletedFromPath;
      affected += 1;
      // 还原该文件夹下被一并软删的子孙文件夹与文档（按时间相近批量找回）。
      const descendants = collectDescendantFolderIds(rootId);
      for (const childId of descendants) {
        const child = findFolder(childId);
        if (child && child.status === 'deleted') {
          child.status = 'active';
          child.updatedAt = now;
          delete child.deletedAt;
          delete child.deletedFromPath;
          affected += 1;
        }
      }
    };

    state.folders.forEach((folder) => {
      if (ids.has(folder.id)) {
        restoreFolderTree(folder.id);
      }
    });

    // 还原随之被软删的文档（归属在被还原文件夹及其子孙下的文档）。
    const restoredFolderIds = new Set(
      state.folders
        .filter((folder) => folder.status === 'active' && ids.has(folder.id))
        .flatMap((folder) => [folder.id, ...collectDescendantFolderIds(folder.id)]),
    );
    state.documents.forEach((document) => {
      if (
        document.status === 'deleted' &&
        document.kind === 'note' &&
        document.folderId &&
        restoredFolderIds.has(document.folderId)
      ) {
        document.status = 'active';
        document.updatedAt = now;
        delete document.deletedAt;
        delete document.deletedFromPath;
        affected += 1;
      }
    });
  } else {
    state.documents.forEach((document) => {
      if (!ids.has(document.id) || document.status !== 'deleted') {
        return;
      }
      // 还原文档时若原父文件夹仍处于删除态，回到根目录。
      const parentStillDeleted =
        document.folderId !== null &&
        (findFolder(document.folderId)?.status === 'deleted' ||
          !hasActiveAncestor(document.folderId));
      const nextFolderId = parentStillDeleted ? null : document.folderId;
      document.folderId = nextFolderId;
      document.status = 'active';
      document.updatedAt = now;
      delete document.deletedAt;
      delete document.deletedFromPath;
      affected += 1;
    });
  }

  persist();
  return affected;
}

export function purgeTrashItems(payload: PurgeTrashItemsPayload): number {
  const ids = new Set(payload.itemIds);
  // 彻底删除为物理删除，仅作用于已软删除项，执行后不可恢复。
  if (payload.itemType === 'folder') {
    const before = state.folders.length;
    state = {
      ...state,
      folders: state.folders.filter(
        (folder) => !(ids.has(folder.id) && folder.status === 'deleted'),
      ),
    };
    return before - state.folders.length;
  }

  const before = state.documents.length;
  state = {
    ...state,
    documents: state.documents.filter(
      (document) => !(ids.has(document.id) && document.status === 'deleted'),
    ),
  };
  return before - state.documents.length;
}

/* ============================ 跨文档搜索 ============================ */

export interface KnowledgeSearchHit {
  id: string;
  /** 标题命中还是正文命中。 */
  matchedField: 'title' | 'content';
  title: string;
  snippet: string;
  location: string;
  kind: string;
  date?: string;
  updatedAt: string;
}

/**
 * 在文档标题与正文中检索关键词（只读，不影响数据）。
 * 命中标题的优先靠前；正文命中返回首次出现位置附近的片段。
 */
export function searchKnowledgeDocuments(keyword: string): KnowledgeSearchHit[] {
  const trimmed = keyword.trim();
  if (!trimmed) {
    return [];
  }
  const lower = trimmed.toLowerCase();
  const results: KnowledgeSearchHit[] = [];

  for (const document of state.documents) {
    if (document.status === 'deleted') {
      continue;
    }
    const summary = hydrateDocument(document);
    const sourceDaily =
      document.kind === 'daily' && document.date ? getDailySourceDocument(document.date) : null;
    const content = sourceDaily?.content ?? document.content;
    const titleLower = document.title.toLowerCase();
    const contentLower = content.toLowerCase();

    const titleHit = titleLower.includes(lower);
    const contentIndex = contentLower.indexOf(lower);

    if (!titleHit && contentIndex === -1) {
      continue;
    }

    const snippet = contentIndex >= 0 ? buildSnippet(content, contentIndex, lower) : summary.excerpt;

    results.push({
      id: document.id,
      matchedField: titleHit ? 'title' : 'content',
      title: document.title,
      snippet,
      location: summary.folderPath || (document.kind === 'daily' ? '每日记录' : '根目录'),
      kind: document.kind === 'daily' ? '每日文档' : 'Markdown 文档',
      date: document.date,
      updatedAt: summary.updatedAt,
    });
  }

  // 标题命中的结果排在正文命中之前，再按更新时间倒序。
  return results.sort((left, right) => {
    if (left.matchedField !== right.matchedField) {
      return left.matchedField === 'title' ? -1 : 1;
    }
    return dayjs(right.updatedAt).valueOf() - dayjs(left.updatedAt).valueOf();
  });
}

function buildSnippet(content: string, index: number, keyword: string): string {
  const radius = 28;
  const start = Math.max(0, index - radius);
  const end = Math.min(content.length, index + keyword.length + radius);
  const raw = content.slice(start, end).replace(/\s+/g, ' ').trim();
  const prefix = start > 0 ? '…' : '';
  const suffix = end < content.length ? '…' : '';
  return `${prefix}${raw}${suffix}`;
}
