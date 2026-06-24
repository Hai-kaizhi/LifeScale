import { Button, Dropdown, Empty, Input, Modal, Skeleton, message } from 'antd';
import type { MenuProps } from 'antd';
import {
  DownOutlined,
  FileMarkdownOutlined,
  FolderFilled,
  MoreOutlined,
  PlusOutlined,
  RightOutlined,
} from '@ant-design/icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import type { VaultNodeKind } from '../../shared/types/vault';
import type { VaultTreeNode, VaultTreeSyncHint } from '../../hooks/useVaultTree';
import './VaultTreePanel.css';

interface VaultTreePanelProps {
  className?: string;
  title: string;
  tree: VaultTreeNode[];
  loading: boolean;
  syncHint: VaultTreeSyncHint | null;
  selectedPath: string | null;
  selectedKind: VaultNodeKind | null;
  expandedPaths: Set<string>;
  onOpenNode: (node: VaultTreeNode) => void;
  onToggleExpanded: (path: string) => void;
  onCreateFile: (parentPath: string | null) => Promise<void>;
  onCreateFolder: (parentPath: string | null) => Promise<void>;
  onRenameNode: (node: VaultTreeNode, nextName: string) => Promise<string | null>;
  onDeleteNode: (node: VaultTreeNode) => Promise<void>;
}

interface VaultTreeRowProps {
  node: VaultTreeNode;
  selectedPath: string | null;
  selectedKind: VaultNodeKind | null;
  expandedPaths: Set<string>;
  editingPath: string | null;
  editingValue: string;
  editingSubmitting: boolean;
  onOpenNode: (node: VaultTreeNode) => void;
  onToggleExpanded: (path: string) => void;
  onCreateFile: (parentPath: string | null) => Promise<void>;
  onCreateFolder: (parentPath: string | null) => Promise<void>;
  onStartRename: (node: VaultTreeNode) => void;
  onRenameValueChange: (value: string) => void;
  onSubmitRename: () => Promise<void>;
  onCancelRename: () => void;
  onDeleteNode: (node: VaultTreeNode) => Promise<void>;
  onCopyPath: (path: string) => Promise<void>;
}

function buildCreateMenuItems(parentPath: string | null): MenuProps['items'] {
  return [
    { key: `file:${parentPath ?? ''}`, label: '新建文件' },
    { key: `folder:${parentPath ?? ''}`, label: '新建文件夹' },
  ];
}

function getFolderContextItems(): MenuProps['items'] {
  return [
    { key: 'create-file', label: '新建文件' },
    { key: 'create-folder', label: '新建文件夹' },
    { type: 'divider' },
    { key: 'rename', label: '重命名' },
    { key: 'copy', label: '复制相对路径' },
    { type: 'divider' },
    { key: 'delete', danger: true, label: '删除文件夹' },
  ];
}

function getFileContextItems(): MenuProps['items'] {
  return [
    { key: 'create-file', label: '在同级新建文件' },
    { key: 'create-folder', label: '在同级新建文件夹' },
    { type: 'divider' },
    { key: 'rename', label: '重命名' },
    { key: 'copy', label: '复制相对路径' },
    { type: 'divider' },
    { key: 'delete', danger: true, label: '删除文件' },
  ];
}

function toneClassName(syncHint: VaultTreeSyncHint | null): string {
  if (!syncHint) {
    return '';
  }
  return `is-${syncHint.tone}`;
}

function VaultTreeRow({
  node,
  selectedPath,
  selectedKind,
  expandedPaths,
  editingPath,
  editingValue,
  editingSubmitting,
  onOpenNode,
  onToggleExpanded,
  onCreateFile,
  onCreateFolder,
  onStartRename,
  onRenameValueChange,
  onSubmitRename,
  onCancelRename,
  onDeleteNode,
  onCopyPath,
}: VaultTreeRowProps) {
  const isSelected = node.path === selectedPath && node.kind === selectedKind;
  const isExpanded = node.kind === 'folder' && expandedPaths.has(node.path);
  const isEditing = editingPath === node.path;
  const createParentPath = node.kind === 'folder' ? node.path : node.parentPath;
  const indentStyle = useMemo(
    () => ({ paddingLeft: `${10 + node.depth * 16}px` }),
    [node.depth],
  );

  const handleContextAction = useCallback(
    async ({ key }: { key: string }) => {
      if (key === 'create-file') {
        await onCreateFile(createParentPath);
        return;
      }
      if (key === 'create-folder') {
        await onCreateFolder(createParentPath);
        return;
      }
      if (key === 'rename') {
        onStartRename(node);
        return;
      }
      if (key === 'copy') {
        await onCopyPath(node.path);
        return;
      }
      if (key === 'delete') {
        await onDeleteNode(node);
      }
    },
    [createParentPath, node, onCopyPath, onCreateFile, onCreateFolder, onDeleteNode, onStartRename],
  );

  const contextMenu: MenuProps = {
    items: node.kind === 'folder' ? getFolderContextItems() : getFileContextItems(),
    onClick: handleContextAction,
  };

  return (
    <Dropdown menu={contextMenu} trigger={['contextMenu']}>
      <div>
        <div
          className={`vault-tree-row${isSelected ? ' is-selected' : ''}${node.kind === 'folder' ? ' is-folder' : ' is-file'}${isEditing ? ' is-editing' : ''}`}
          style={indentStyle}
        >
          {node.kind === 'folder' ? (
            <button
              type="button"
              className="vault-tree-caret"
              onClick={(event) => {
                event.stopPropagation();
                onToggleExpanded(node.path);
              }}
              aria-label={isExpanded ? '折叠文件夹' : '展开文件夹'}
            >
              {isExpanded ? <DownOutlined /> : <RightOutlined />}
            </button>
          ) : (
            <span className="vault-tree-caret is-empty" aria-hidden="true" />
          )}

          <div className="vault-tree-main">
            <button
              type="button"
              className="vault-tree-main-trigger"
              onClick={() => onOpenNode(node)}
            >
              <span className={`vault-tree-icon is-${node.kind}`} aria-hidden="true">
                {node.kind === 'folder' ? <FolderFilled /> : <FileMarkdownOutlined />}
              </span>
            </button>

            {isEditing ? (
              <div
                className="vault-tree-inline-rename"
                onClick={(event) => event.stopPropagation()}
              >
                <Input
                  autoFocus
                  size="small"
                  value={editingValue}
                  disabled={editingSubmitting}
                  className="vault-tree-inline-input"
                  placeholder={node.kind === 'folder' ? '文件夹名称' : '文件名称'}
                  onChange={(event) => onRenameValueChange(event.target.value)}
                  onBlur={() => void onSubmitRename()}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter') {
                      event.preventDefault();
                      event.currentTarget.blur();
                    }
                    if (event.key === 'Escape') {
                      event.preventDefault();
                      onCancelRename();
                    }
                  }}
                />
                {node.kind === 'file' && <span className="vault-tree-inline-ext">.md</span>}
              </div>
            ) : (
              <button
                type="button"
                className="vault-tree-main-trigger vault-tree-main-label-trigger"
                onClick={() => onOpenNode(node)}
              >
                <span className="vault-tree-label">{node.name}</span>
              </button>
            )}
          </div>

          <div className="vault-tree-actions">
            {node.kind === 'folder' && (
              <Dropdown menu={{ items: getFolderContextItems(), onClick: handleContextAction }} trigger={['click']}>
                <button
                  type="button"
                  className="vault-tree-action-button"
                  onClick={(event) => event.stopPropagation()}
                  aria-label="更多操作"
                >
                  <MoreOutlined />
                </button>
              </Dropdown>
            )}

            <Dropdown
              menu={{
                items: buildCreateMenuItems(createParentPath),
                onClick: async ({ key }) => {
                  if (String(key).startsWith('file:')) {
                    await onCreateFile(createParentPath);
                    return;
                  }
                  await onCreateFolder(createParentPath);
                },
              }}
              trigger={['click']}
            >
              <button
                type="button"
                className="vault-tree-action-button"
                onClick={(event) => event.stopPropagation()}
                aria-label="新建"
              >
                <PlusOutlined />
              </button>
            </Dropdown>
          </div>
        </div>

        {node.kind === 'folder' && isExpanded && node.children.length > 0 && (
          <div className="vault-tree-children">
            {node.children.map((child) => (
              <VaultTreeRow
                key={`${child.kind}:${child.path}`}
                node={child}
                selectedPath={selectedPath}
                selectedKind={selectedKind}
                expandedPaths={expandedPaths}
                editingPath={editingPath}
                editingValue={editingValue}
                editingSubmitting={editingSubmitting}
                onOpenNode={onOpenNode}
                onToggleExpanded={onToggleExpanded}
                onCreateFile={onCreateFile}
                onCreateFolder={onCreateFolder}
                onStartRename={onStartRename}
                onRenameValueChange={onRenameValueChange}
                onSubmitRename={onSubmitRename}
                onCancelRename={onCancelRename}
                onDeleteNode={onDeleteNode}
                onCopyPath={onCopyPath}
              />
            ))}
          </div>
        )}
      </div>
    </Dropdown>
  );
}

export function VaultTreePanel({
  className,
  title,
  tree,
  loading,
  syncHint,
  selectedPath,
  selectedKind,
  expandedPaths,
  onOpenNode,
  onToggleExpanded,
  onCreateFile,
  onCreateFolder,
  onRenameNode,
  onDeleteNode,
}: VaultTreePanelProps) {
  const [renameTarget, setRenameTarget] = useState<VaultTreeNode | null>(null);
  const [renameValue, setRenameValue] = useState('');
  const [renameSubmitting, setRenameSubmitting] = useState(false);

  useEffect(() => {
    if (!renameTarget) {
      return;
    }
    const stillExists = tree.some((node) => {
      const stack = [node];
      while (stack.length > 0) {
        const current = stack.pop();
        if (!current) {
          continue;
        }
        if (current.path === renameTarget.path) {
          return true;
        }
        stack.push(...current.children);
      }
      return false;
    });
    if (!stillExists) {
      setRenameTarget(null);
      setRenameValue('');
      setRenameSubmitting(false);
    }
  }, [renameTarget, tree]);

  const handleCopyPath = useCallback(async (path: string) => {
    try {
      await navigator.clipboard.writeText(path);
      message.success('已复制相对路径');
    } catch {
      message.error('复制失败');
    }
  }, []);

  const handleDelete = useCallback(
    async (node: VaultTreeNode) => {
      Modal.confirm({
        centered: true,
        title: node.kind === 'folder' ? '删除文件夹？' : '删除文件？',
        content:
          node.kind === 'folder'
            ? node.descendantFileCount > 0
              ? `「${node.name}」下有 ${node.descendantFileCount} 个 Markdown 文件，删除后会一起进入待同步删除。`
              : `「${node.name}」是空文件夹，删除后会立即从本地工作区移除。`
            : `「${node.name}」会从当前工作区删除，并进入待同步删除。`,
        okText: '确认删除',
        okButtonProps: { danger: true },
        cancelText: '取消',
        onOk: () => onDeleteNode(node),
      });
    },
    [onDeleteNode],
  );

  const handleStartRename = useCallback((node: VaultTreeNode) => {
    setRenameTarget(node);
    setRenameValue(node.kind === 'file' ? node.name.replace(/\.md$/i, '') : node.name);
  }, []);

  const handleCancelRename = useCallback(() => {
    if (renameSubmitting) {
      return;
    }
    setRenameTarget(null);
    setRenameValue('');
  }, [renameSubmitting]);

  const handleSubmitRename = useCallback(async () => {
    if (!renameTarget || renameSubmitting) {
      return;
    }
    setRenameSubmitting(true);
    try {
      const nextPath = await onRenameNode(renameTarget, renameValue);
      if (nextPath) {
        setRenameTarget(null);
        setRenameValue('');
      }
    } finally {
      setRenameSubmitting(false);
    }
  }, [onRenameNode, renameSubmitting, renameTarget, renameValue]);

  const rootCreateMenu: MenuProps = {
    items: buildCreateMenuItems(null),
    onClick: async ({ key }) => {
      if (String(key).startsWith('file:')) {
        await onCreateFile(null);
        return;
      }
      await onCreateFolder(null);
    },
  };

  const panelClassName = className ? `vault-tree-panel ${className}` : 'vault-tree-panel';

  return (
    <section className={panelClassName} aria-label={title}>
      <div className="vault-tree-toolbar">
        <div className="vault-tree-toolbar-copy">
          <span className="vault-tree-title">{title}</span>
          {syncHint && (
            <span className={`vault-tree-sync-badge ${toneClassName(syncHint)}`}>
              {syncHint.label}
            </span>
          )}
        </div>

        <Dropdown menu={rootCreateMenu} trigger={['click']}>
          <Button
            type="text"
            className="vault-tree-toolbar-create"
            icon={<PlusOutlined />}
          />
        </Dropdown>
      </div>

      <div className="vault-tree-scroll">
        {loading ? (
          <div className="vault-tree-loading">
            <Skeleton active title={false} paragraph={{ rows: 8 }} />
          </div>
        ) : tree.length > 0 ? (
          tree.map((node) => (
            <VaultTreeRow
              key={`${node.kind}:${node.path}`}
              node={node}
              selectedPath={selectedPath}
              selectedKind={selectedKind}
              expandedPaths={expandedPaths}
              editingPath={renameTarget?.path ?? null}
              editingValue={renameValue}
              editingSubmitting={renameSubmitting}
              onOpenNode={onOpenNode}
              onToggleExpanded={onToggleExpanded}
              onCreateFile={onCreateFile}
              onCreateFolder={onCreateFolder}
              onStartRename={handleStartRename}
              onRenameValueChange={setRenameValue}
              onSubmitRename={handleSubmitRename}
              onCancelRename={handleCancelRename}
              onDeleteNode={handleDelete}
              onCopyPath={handleCopyPath}
            />
          ))
        ) : (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="空工作区"
            className="vault-tree-empty"
          />
        )}
      </div>
    </section>
  );
}
