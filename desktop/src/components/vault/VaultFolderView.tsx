import { Breadcrumb, Button, Dropdown, Empty, Input, Modal, Space, Table, Tag, message } from 'antd';
import type { MenuProps, TableColumnsType } from 'antd';
import {
  CopyOutlined,
  DeleteOutlined,
  FileMarkdownOutlined,
  FolderFilled,
  PlusOutlined,
} from '@ant-design/icons';
import { useCallback, useEffect, useMemo, useState, type Key } from 'react';
import type { SyncStateRow, VaultNodeKind, VaultSyncStatus } from '../../shared/types/vault';
import type { VaultTreeNode } from '../../hooks/useVaultTree';
import { isVaultPathWithin } from '../../hooks/useVaultTree';
import { listAllSyncState } from '../../services/vault/syncState';

type DirectorySyncKind = 'synced' | 'unsynced' | 'syncing' | 'conflict' | 'deleted' | 'local';

interface VaultDirectoryRow {
  key: string;
  node: VaultTreeNode;
  path: string;
  name: string;
  kind: VaultNodeKind;
  typeLabel: string;
  createdAt: number | null;
  updatedAt: number | null;
  markdownCount: number;
  syncKind: DirectorySyncKind;
  syncLabel: string;
}

interface VaultFolderViewProps {
  title: string;
  items: VaultTreeNode[];
  breadcrumbs: Array<{ key: string; label: string; path: string | null }>;
  onOpenPath: (path: string | null, kind: VaultNodeKind) => void;
  onCreateFile: (parentPath: string | null) => Promise<void>;
  onCreateFolder: (parentPath: string | null) => Promise<void>;
  onRenameNode: (node: VaultTreeNode, nextName: string) => Promise<string | null>;
  onDeleteNode: (node: VaultTreeNode) => Promise<void>;
  currentPath: string | null;
  vaultRoot: string | null;
  syncStatus: VaultSyncStatus;
  titleEditable?: boolean;
  titleDraft?: string;
  titleSaving?: boolean;
  onTitleChange?: (value: string) => void;
  onTitleSubmit?: () => Promise<void>;
  onTitleCancel?: () => void;
}

const SYNCING_PHASES = new Set<VaultSyncStatus['phase']>([
  'pushing',
  'pulling',
  'applying',
]);

const STATUS_VIEW: Record<DirectorySyncKind, { label: string; color: string }> = {
  synced: { label: '已同步', color: 'success' },
  unsynced: { label: '未同步', color: 'warning' },
  syncing: { label: '正在同步', color: 'processing' },
  conflict: { label: '冲突', color: 'error' },
  deleted: { label: '待删除', color: 'default' },
  local: { label: '仅本地', color: 'default' },
};

function collectMarkdownPaths(node: VaultTreeNode): string[] {
  if (node.kind === 'file') {
    return [node.path];
  }
  const out: string[] = [];
  const stack = [...node.children];
  while (stack.length > 0) {
    const current = stack.pop();
    if (!current) {
      continue;
    }
    if (current.kind === 'file') {
      out.push(current.path);
    } else {
      stack.push(...current.children);
    }
  }
  return out;
}

function isNodeSyncing(node: VaultTreeNode, syncStatus: VaultSyncStatus): boolean {
  const activePath = syncStatus.activeVaultPath;
  if (!activePath || !SYNCING_PHASES.has(syncStatus.phase)) {
    return false;
  }
  return node.kind === 'file' ? node.path === activePath : isVaultPathWithin(activePath, node.path);
}

function resolveRowStatus(
  node: VaultTreeNode,
  stateByPath: Map<string, SyncStateRow>,
  syncStatus: VaultSyncStatus,
): DirectorySyncKind {
  if (isNodeSyncing(node, syncStatus)) {
    return 'syncing';
  }

  const paths = collectMarkdownPaths(node);
  if (paths.length === 0) {
    return 'local';
  }

  const states = paths.map((path) => stateByPath.get(path));
  if (states.some((state) => state?.status === 'conflict')) {
    return 'conflict';
  }
  if (states.some((state) => state?.status === 'deleted')) {
    return 'deleted';
  }
  if (states.some((state) => !state || state.status === 'dirty' || state.status === 'pending')) {
    return 'unsynced';
  }
  if (states.every((state) => state?.status === 'clean')) {
    return 'synced';
  }
  return 'local';
}

function formatTimestamp(value: number | null): string {
  if (!value) {
    return '-';
  }
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function initialRenameValue(row: VaultDirectoryRow): string {
  return row.kind === 'file' ? row.name.replace(/\.md$/i, '') : row.name;
}

function countMarkdownFiles(rows: VaultDirectoryRow[]): number {
  return rows.reduce((total, row) => total + row.markdownCount, 0);
}

export function VaultFolderView({
  title,
  items,
  breadcrumbs,
  onOpenPath,
  onCreateFile,
  onCreateFolder,
  onRenameNode,
  onDeleteNode,
  currentPath,
  vaultRoot,
  syncStatus,
  titleEditable = false,
  titleDraft = '',
  titleSaving = false,
  onTitleChange,
  onTitleSubmit,
  onTitleCancel,
}: VaultFolderViewProps) {
  const [syncRows, setSyncRows] = useState<SyncStateRow[]>([]);
  const [selectedRowKeys, setSelectedRowKeys] = useState<Key[]>([]);
  const [editingPath, setEditingPath] = useState<string | null>(null);
  const [editingValue, setEditingValue] = useState('');
  const [editingSubmitting, setEditingSubmitting] = useState(false);

  const createMenu: MenuProps = {
    items: [
      { key: 'file', label: '新建文件' },
      { key: 'folder', label: '新建文件夹' },
    ],
    onClick: async ({ key }) => {
      if (key === 'file') {
        await onCreateFile(currentPath);
        return;
      }
      await onCreateFolder(currentPath);
    },
  };

  useEffect(() => {
    let alive = true;
    if (!vaultRoot) {
      setSyncRows([]);
      return () => {
        alive = false;
      };
    }
    void listAllSyncState(vaultRoot)
      .then((rows) => {
        if (alive) {
          setSyncRows(rows);
        }
      })
      .catch(() => {
        if (alive) {
          setSyncRows([]);
        }
      });
    return () => {
      alive = false;
    };
  }, [syncStatus.conflict, syncStatus.lastSyncAt, syncStatus.pending, syncStatus.phase, vaultRoot]);

  const stateByPath = useMemo(
    () => new Map(syncRows.map((row) => [row.vaultPath, row])),
    [syncRows],
  );

  const rows = useMemo<VaultDirectoryRow[]>(
    () =>
      items.map((item) => {
        const syncKind = resolveRowStatus(item, stateByPath, syncStatus);
        return {
          key: item.path,
          node: item,
          path: item.path,
          name: item.name,
          kind: item.kind,
          typeLabel: item.kind === 'folder' ? '文件夹' : 'Markdown',
          createdAt: item.ctime ?? item.mtime ?? null,
          updatedAt: item.mtime ?? item.ctime ?? null,
          markdownCount: item.kind === 'file' ? 1 : item.descendantFileCount,
          syncKind,
          syncLabel: STATUS_VIEW[syncKind].label,
        };
      }),
    [items, stateByPath, syncStatus],
  );

  useEffect(() => {
    const keys = new Set(rows.map((row) => row.key));
    setSelectedRowKeys((current) => current.filter((key) => keys.has(String(key))));
  }, [rows]);

  const selectedRows = useMemo(() => {
    const keys = new Set(selectedRowKeys.map(String));
    return rows.filter((row) => keys.has(row.key));
  }, [rows, selectedRowKeys]);

  const copyPaths = useCallback(async (paths: string[]) => {
    try {
      await navigator.clipboard.writeText(paths.join('\n'));
      message.success(paths.length > 1 ? '已复制所选路径' : '已复制相对路径');
    } catch {
      message.error('复制失败');
    }
  }, []);

  const startRename = useCallback((row: VaultDirectoryRow) => {
    setEditingPath(row.path);
    setEditingValue(initialRenameValue(row));
  }, []);

  const cancelRename = useCallback(() => {
    if (editingSubmitting) {
      return;
    }
    setEditingPath(null);
    setEditingValue('');
  }, [editingSubmitting]);

  const submitRename = useCallback(
    async (row: VaultDirectoryRow) => {
      if (editingSubmitting || editingPath !== row.path) {
        return;
      }
      const nextName = editingValue.trim();
      if (!nextName) {
        cancelRename();
        return;
      }
      if (nextName === initialRenameValue(row)) {
        cancelRename();
        return;
      }
      setEditingSubmitting(true);
      try {
        const nextPath = await onRenameNode(row.node, nextName);
        if (nextPath) {
          setEditingPath(null);
          setEditingValue('');
        }
      } finally {
        setEditingSubmitting(false);
      }
    },
    [cancelRename, editingPath, editingSubmitting, editingValue, onRenameNode],
  );

  const confirmDeleteRows = useCallback(
    (targetRows: VaultDirectoryRow[]) => {
      if (targetRows.length === 0) {
        return;
      }
      const markdownCount = countMarkdownFiles(targetRows);
      Modal.confirm({
        centered: true,
        title: targetRows.length > 1 ? '删除所选项目？' : targetRows[0].kind === 'folder' ? '删除文件夹？' : '删除文件？',
        content:
          targetRows.length > 1
            ? `将删除 ${targetRows.length} 个项目，涉及 ${markdownCount} 个 Markdown 文件。`
            : targetRows[0].kind === 'folder'
              ? `「${targetRows[0].name}」下有 ${markdownCount} 个 Markdown 文件，删除后会一起进入待同步删除。`
              : `「${targetRows[0].name}」会从当前工作区删除，并进入待同步删除。`,
        okText: '确认删除',
        okButtonProps: { danger: true },
        cancelText: '取消',
        onOk: async () => {
          for (const row of targetRows) {
            await onDeleteNode(row.node);
          }
          setSelectedRowKeys([]);
        },
      });
    },
    [onDeleteNode],
  );

  const columns = useMemo<TableColumnsType<VaultDirectoryRow>>(
    () => [
      {
        title: '名称',
        dataIndex: 'name',
        key: 'name',
        width: 'clamp(180px, 32vw, 360px)',
        className: 'vault-folder-name-column',
        sorter: (left, right) => {
          if (left.kind !== right.kind) {
            return left.kind === 'folder' ? -1 : 1;
          }
          return left.name.localeCompare(right.name, 'zh-CN', {
            numeric: true,
            sensitivity: 'base',
          });
        },
        render: (_, row) => {
          const isEditing = editingPath === row.path;
          return (
            <div className="vault-folder-name-cell">
              <span className={`vault-folder-name-icon is-${row.kind}`} aria-hidden="true">
                {row.kind === 'folder' ? <FolderFilled /> : <FileMarkdownOutlined />}
              </span>
              {isEditing ? (
                <span className="vault-folder-name-edit">
                  <Input
                    autoFocus
                    size="small"
                    value={editingValue}
                    disabled={editingSubmitting}
                    onChange={(event) => setEditingValue(event.target.value)}
                    onBlur={() => void submitRename(row)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter') {
                        event.preventDefault();
                        event.currentTarget.blur();
                      }
                      if (event.key === 'Escape') {
                        event.preventDefault();
                        cancelRename();
                      }
                    }}
                  />
                  {row.kind === 'file' && <span className="vault-folder-name-ext">.md</span>}
                </span>
              ) : (
                <button
                  type="button"
                  className="vault-folder-name-button"
                  onClick={() => onOpenPath(row.path, row.kind)}
                >
                  {row.name}
                </button>
              )}
            </div>
          );
        },
      },
      {
        title: '类型',
        dataIndex: 'typeLabel',
        key: 'type',
        width: 96,
        responsive: ['md'],
      },
      {
        title: '创建时间',
        dataIndex: 'createdAt',
        key: 'createdAt',
        width: 148,
        responsive: ['lg'],
        sorter: (left, right) => (left.createdAt ?? 0) - (right.createdAt ?? 0),
        render: (value: number | null) => formatTimestamp(value),
      },
      {
        title: '更新时间',
        dataIndex: 'updatedAt',
        key: 'updatedAt',
        width: 148,
        responsive: ['lg'],
        sorter: (left, right) => (left.updatedAt ?? 0) - (right.updatedAt ?? 0),
        render: (value: number | null) => formatTimestamp(value),
      },
      {
        title: '状态',
        dataIndex: 'syncLabel',
        key: 'sync',
        width: 108,
        render: (_, row) => (
          <Tag color={STATUS_VIEW[row.syncKind].color} className="vault-folder-status-tag">
            {row.syncLabel}
          </Tag>
        ),
      },
      {
        title: '操作',
        key: 'actions',
        width: 220,
        render: (_, row) => (
          <Space size={4} className="vault-folder-actions">
            <Button type="link" size="small" onClick={() => onOpenPath(row.path, row.kind)}>
              打开
            </Button>
            <Button type="link" size="small" onClick={() => startRename(row)}>
              重命名
            </Button>
            <Button type="link" size="small" onClick={() => void copyPaths([row.path])}>
              复制路径
            </Button>
            <Button danger type="link" size="small" onClick={() => confirmDeleteRows([row])}>
              删除
            </Button>
          </Space>
        ),
      },
    ],
    [
      cancelRename,
      confirmDeleteRows,
      copyPaths,
      editingPath,
      editingSubmitting,
      editingValue,
      onOpenPath,
      startRename,
      submitRename,
    ],
  );

  return (
    <section className="vault-folder-view">
      <div className="vault-folder-view-header">
        <div className="vault-folder-view-copy">
          <Breadcrumb
            className="vault-folder-breadcrumb"
            items={breadcrumbs.map((item) => ({
              title: (
                <button
                  type="button"
                  className="vault-folder-breadcrumb-link"
                  onClick={() => onOpenPath(item.path, 'folder')}
                >
                  {item.label}
                </button>
              ),
              key: item.key,
            }))}
          />
          {titleEditable ? (
            <div className="vault-editor-title-row is-folder">
              <input
                type="text"
                className="vault-editor-title-input"
                value={titleDraft}
                aria-label="编辑文件夹名称"
                onChange={(event) => onTitleChange?.(event.target.value)}
                onBlur={() => {
                  if (onTitleSubmit) {
                    void onTitleSubmit();
                  }
                }}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') {
                    event.preventDefault();
                    event.currentTarget.blur();
                  }
                  if (event.key === 'Escape') {
                    onTitleCancel?.();
                    event.currentTarget.blur();
                  }
                }}
              />
            </div>
          ) : (
            <h2>{title}</h2>
          )}
          {titleSaving && <span className="vault-editor-saving">正在保存文件夹名称...</span>}
        </div>

        <Dropdown menu={createMenu} trigger={['click']}>
          <Button type="primary" icon={<PlusOutlined />}>
            新建
          </Button>
        </Dropdown>
      </div>

      <div className="vault-folder-table-wrap">
        {selectedRows.length > 0 && (
          <div className="vault-folder-bulkbar">
            <span>
              已选择 {selectedRows.length} 项，包含 {countMarkdownFiles(selectedRows)} 个 Markdown 文件
            </span>
            <Space size={8}>
              <Button size="small" icon={<CopyOutlined />} onClick={() => void copyPaths(selectedRows.map((row) => row.path))}>
                复制路径
              </Button>
              <Button size="small" danger icon={<DeleteOutlined />} onClick={() => confirmDeleteRows(selectedRows)}>
                批量删除
              </Button>
              <Button size="small" type="text" onClick={() => setSelectedRowKeys([])}>
                清除选择
              </Button>
            </Space>
          </div>
        )}

        <Table<VaultDirectoryRow>
          className="vault-folder-table"
          rowKey="key"
          size="middle"
          tableLayout="fixed"
          columns={columns}
          dataSource={rows}
          pagination={false}
          scroll={{ x: 'max-content' }}
          rowSelection={{
            selectedRowKeys,
            onChange: (keys) => setSelectedRowKeys(keys),
          }}
          locale={{
            emptyText: (
              <Empty
                image={Empty.PRESENTED_IMAGE_SIMPLE}
                description="这个目录还是空的"
                className="vault-folder-empty"
              >
                <Dropdown menu={createMenu} trigger={['click']}>
                  <Button type="primary" icon={<PlusOutlined />}>
                    新建文件或文件夹
                  </Button>
                </Dropdown>
              </Empty>
            ),
          }}
        />
      </div>
    </section>
  );
}
