import { Button, Empty, Spin } from 'antd';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { useVaultSync } from '../hooks/useVaultSync';
import { isVaultPathWithin, useVaultTree, type VaultTreeNode } from '../hooks/useVaultTree';
import { useVaultDocumentEditor } from '../hooks/vault/useVaultDocumentEditor';
import { ROUTES } from '../shared/constants';
import { buildVaultRoute } from '../shared/utils/vaultRoute';
import { ToastMarkdownEditor } from '../components/knowledge/ToastMarkdownEditor';
import { VaultFolderView } from '../components/vault/VaultFolderView';
import './VaultNotesPage.css';

function buildFolderBreadcrumbs(path: string | null) {
  const items = [{ key: 'root', label: '工作区', path: null as string | null }];
  if (!path) {
    return items;
  }
  const parts = path.split('/').filter(Boolean);
  for (let index = 0; index < parts.length; index += 1) {
    items.push({
      key: `${index}:${parts[index]}`,
      label: parts[index],
      path: parts.slice(0, index + 1).join('/'),
    });
  }
  return items;
}

function getParentPath(path: string | null): string | null {
  if (!path) {
    return null;
  }
  const parts = path.split('/').filter(Boolean);
  if (parts.length <= 1) {
    return null;
  }
  return parts.slice(0, -1).join('/');
}

export function VaultNotesPage() {
  const navigate = useNavigate();
  const { vaultRoot, chooseVaultFolder, status } = useVaultSync();
  const {
    selectedNode,
    selectedKind,
    selectedPath,
    setExpanded,
    createFile,
    createFolder,
    renameNode,
    deleteNode,
    getFolderChildren,
  } = useVaultTree();
  const filePath = selectedKind === 'file' && selectedNode?.kind === 'file' ? selectedNode.path : null;
  const { content, onChange, loading: documentLoading } = useVaultDocumentEditor(filePath);
  const [titleDraft, setTitleDraft] = useState('');
  const [titleSaving, setTitleSaving] = useState(false);
  const [folderTitleDraft, setFolderTitleDraft] = useState('');
  const [folderTitleSaving, setFolderTitleSaving] = useState(false);

  const openPath = useCallback(
    (path: string | null, kind: 'file' | 'folder') => {
      if (path && kind === 'folder') {
        setExpanded(path, true);
      }
      navigate(buildVaultRoute(path, kind));
    },
    [navigate, setExpanded],
  );

  const handleCreateFile = useCallback(
    async (parentPath: string | null) => {
      const nextPath = await createFile(parentPath);
      if (!nextPath) {
        return;
      }
      if (parentPath) {
        setExpanded(parentPath, true);
      }
      navigate(buildVaultRoute(nextPath, 'file'));
    },
    [createFile, navigate, setExpanded],
  );

  const handleCreateFolder = useCallback(
    async (parentPath: string | null) => {
      const nextPath = await createFolder(parentPath);
      if (!nextPath) {
        return;
      }
      if (parentPath) {
        setExpanded(parentPath, true);
      }
      navigate(buildVaultRoute(nextPath, 'folder'));
    },
    [createFolder, navigate, setExpanded],
  );

  const handleRenameNode = useCallback(
    async (node: VaultTreeNode, nextName: string) => {
      const nextPath = await renameNode(node, nextName);
      if (!nextPath) {
        return null;
      }

      if (selectedPath) {
        if (selectedPath === node.path && selectedKind === node.kind) {
          navigate(buildVaultRoute(nextPath, node.kind), { replace: true });
        } else if (node.kind === 'folder' && isVaultPathWithin(selectedPath, node.path)) {
          const suffix = selectedPath.slice(node.path.length);
          navigate(buildVaultRoute(`${nextPath}${suffix}`, selectedKind ?? 'folder'), {
            replace: true,
          });
        }
      }
      return nextPath;
    },
    [navigate, renameNode, selectedKind, selectedPath],
  );

  const handleDeleteNode = useCallback(
    async (node: VaultTreeNode) => {
      await deleteNode(node);
    },
    [deleteNode],
  );

  const activeFolderPath = selectedKind === 'folder' ? selectedPath : null;
  const activeFolderNode = selectedKind === 'folder' ? selectedNode : null;
  const folderChildren = getFolderChildren(activeFolderPath);
  const folderBreadcrumbs = useMemo(
    () => buildFolderBreadcrumbs(activeFolderPath),
    [activeFolderPath],
  );
  const fileBreadcrumbs = useMemo(
    () => buildFolderBreadcrumbs(selectedNode?.parentPath ?? null).slice(1),
    [selectedNode?.parentPath],
  );
  const missingSelection = Boolean(selectedPath && selectedKind && !selectedNode);
  const missingParentPath = useMemo(() => getParentPath(selectedPath), [selectedPath]);
  const selectedFileTitle =
    selectedNode?.kind === 'file' ? selectedNode.name.replace(/\.md$/i, '') : '';
  const selectedFolderTitle =
    selectedNode?.kind === 'folder' ? selectedNode.name : '';

  useEffect(() => {
    setTitleDraft(selectedFileTitle);
  }, [selectedFileTitle, selectedNode?.path]);

  useEffect(() => {
    setFolderTitleDraft(selectedFolderTitle);
  }, [selectedFolderTitle, selectedNode?.path]);

  const submitFileTitle = useCallback(async () => {
    if (titleSaving || selectedNode?.kind !== 'file') {
      return;
    }

    const nextTitle = titleDraft.trim();
    if (!nextTitle) {
      setTitleDraft(selectedFileTitle);
      return;
    }
    if (nextTitle === selectedFileTitle) {
      return;
    }

    setTitleSaving(true);
    try {
      await handleRenameNode(selectedNode, nextTitle);
    } finally {
      setTitleSaving(false);
    }
  }, [handleRenameNode, selectedFileTitle, selectedNode, titleDraft, titleSaving]);

  const submitFolderTitle = useCallback(async () => {
    if (folderTitleSaving || selectedNode?.kind !== 'folder') {
      return;
    }

    const nextTitle = folderTitleDraft.trim();
    if (!nextTitle) {
      setFolderTitleDraft(selectedFolderTitle);
      return;
    }
    if (nextTitle === selectedFolderTitle) {
      return;
    }

    setFolderTitleSaving(true);
    try {
      await handleRenameNode(selectedNode, nextTitle);
    } finally {
      setFolderTitleSaving(false);
    }
  }, [folderTitleDraft, folderTitleSaving, handleRenameNode, selectedFolderTitle, selectedNode]);

  if (!vaultRoot) {
    return (
      <div className="vault-notes-empty-state">
        <Empty description="尚未选择本地工作区">
          <Button type="primary" onClick={() => void chooseVaultFolder()}>
            选择工作区文件夹
          </Button>
        </Empty>
      </div>
    );
  }

  return (
    <div className="vault-notes-page">
      <section className="vault-notes-main">
        {missingSelection ? (
          <div className="vault-notes-missing">
            <Empty description={selectedKind === 'folder' ? '这个文件夹已不存在' : '这个文件已不存在'}>
              <Button
                onClick={() =>
                  navigate(
                    missingParentPath ? buildVaultRoute(missingParentPath, 'folder') : ROUTES.VAULT,
                    { replace: true },
                  )
                }
              >
                返回工作区
              </Button>
            </Empty>
          </div>
        ) : selectedKind === 'file' ? (
          selectedNode?.kind === 'file' ? (
            <div className="vault-editor-shell">
              <header className="vault-editor-header">
                <div className="vault-editor-copy">
                  {fileBreadcrumbs.length > 0 && (
                    <div className="vault-editor-breadcrumb">
                      {fileBreadcrumbs.map((crumb, index) => (
                        <span key={crumb.key}>
                          <button
                            type="button"
                            className="vault-editor-breadcrumb-link"
                            onClick={() => openPath(crumb.path, 'folder')}
                          >
                            {crumb.label}
                          </button>
                          {index < fileBreadcrumbs.length - 1 && <span>/</span>}
                        </span>
                      ))}
                    </div>
                  )}
                  <div className="vault-editor-title-row">
                    <input
                      type="text"
                      className="vault-editor-title-input"
                      value={titleDraft}
                      aria-label="编辑文件名"
                      onChange={(event) => setTitleDraft(event.target.value)}
                      onBlur={() => void submitFileTitle()}
                      onKeyDown={(event) => {
                        if (event.key === 'Enter') {
                          event.preventDefault();
                          event.currentTarget.blur();
                        }
                        if (event.key === 'Escape') {
                          setTitleDraft(selectedFileTitle);
                          event.currentTarget.blur();
                        }
                      }}
                    />
                    <span className="vault-editor-title-ext">.md</span>
                  </div>
                  <p>{selectedNode.parentPath ? `当前位置：${selectedNode.parentPath}` : '当前位置：根目录'}</p>
                  {titleSaving && <span className="vault-editor-saving">正在保存文件名...</span>}
                </div>
              </header>

              <div className="vault-editor-content">
                {documentLoading ? (
                  <div className="vault-editor-loading">
                    <Spin />
                    <span>正在加载文件...</span>
                  </div>
                ) : (
                  <ToastMarkdownEditor
                    value={content}
                    onChange={onChange}
                    height="calc(100vh - 250px)"
                  />
                )}
              </div>
            </div>
          ) : null
        ) : (
          <VaultFolderView
            title={activeFolderNode?.name ?? '工作区'}
            items={folderChildren}
            breadcrumbs={folderBreadcrumbs}
            currentPath={activeFolderPath}
            vaultRoot={vaultRoot}
            syncStatus={status}
            onOpenPath={openPath}
            onCreateFile={handleCreateFile}
            onCreateFolder={handleCreateFolder}
            onRenameNode={handleRenameNode}
            onDeleteNode={handleDeleteNode}
            titleEditable={Boolean(activeFolderNode)}
            titleDraft={folderTitleDraft}
            titleSaving={folderTitleSaving}
            onTitleChange={setFolderTitleDraft}
            onTitleSubmit={submitFolderTitle}
            onTitleCancel={() => setFolderTitleDraft(selectedFolderTitle)}
          />
        )}
      </section>
    </div>
  );
}
