import { message } from 'antd';
import { startTransition, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation } from 'react-router';
import { useVaultSync } from './useVaultSync';
import { getVaultEngineSingleton } from '../services/vault';
import {
  createVaultDirectory,
  deleteVaultDirectory,
  listVaultTree,
  renameVaultDirectory,
} from '../services/vault/vaultFileBridge';
import type { VaultNodeKind, VaultSyncStatus, VaultTreeEntry } from '../shared/types/vault';

export interface VaultTreeNode extends VaultTreeEntry {
  children: VaultTreeNode[];
  depth: number;
  descendantFileCount: number;
}

export interface VaultTreeSyncHint {
  tone: 'syncing' | 'pending' | 'offline' | 'error';
  label: string;
}

interface BuiltVaultTree {
  tree: VaultTreeNode[];
  entryMap: Map<string, VaultTreeNode>;
}

interface UseVaultTreeResult {
  tree: VaultTreeNode[];
  entryMap: Map<string, VaultTreeNode>;
  selectedNode: VaultTreeNode | null;
  selectedKind: VaultNodeKind | null;
  selectedPath: string | null;
  expandedPaths: Set<string>;
  loading: boolean;
  syncHint: VaultTreeSyncHint | null;
  vaultRoot: string | null;
  refresh: () => Promise<void>;
  toggleExpanded: (path: string) => void;
  setExpanded: (path: string, expanded: boolean) => void;
  createFile: (parentPath: string | null) => Promise<string | null>;
  createFolder: (parentPath: string | null) => Promise<string | null>;
  renameNode: (node: VaultTreeNode, nextName: string) => Promise<string | null>;
  deleteNode: (node: VaultTreeNode) => Promise<boolean>;
  getFolderChildren: (path: string | null) => VaultTreeNode[];
}

function sortByKindAndName(left: VaultTreeEntry, right: VaultTreeEntry): number {
  if (left.kind !== right.kind) {
    return left.kind === 'folder' ? -1 : 1;
  }
  return left.name.localeCompare(right.name, 'zh-CN', {
    numeric: true,
    sensitivity: 'base',
  });
}

function buildVaultTree(entries: VaultTreeEntry[]): BuiltVaultTree {
  const entryMap = new Map<string, VaultTreeNode>();
  for (const entry of entries.slice().sort(sortByKindAndName)) {
    entryMap.set(entry.path, {
      ...entry,
      children: [],
      depth: entry.parentPath ? entry.parentPath.split('/').length : 0,
      descendantFileCount: entry.kind === 'file' ? 1 : 0,
    });
  }

  const tree: VaultTreeNode[] = [];
  for (const node of entryMap.values()) {
    if (node.parentPath && entryMap.has(node.parentPath)) {
      entryMap.get(node.parentPath)?.children.push(node);
    } else {
      tree.push(node);
    }
  }

  const applyCounts = (nodes: VaultTreeNode[]): number => {
    let total = 0;
    nodes.sort(sortByKindAndName);
    for (const node of nodes) {
      if (node.kind === 'file') {
        node.descendantFileCount = 1;
      } else {
        node.descendantFileCount = applyCounts(node.children);
      }
      total += node.descendantFileCount;
    }
    return total;
  };

  applyCounts(tree);
  return { tree, entryMap };
}

function getAncestors(path: string): string[] {
  const parts = path.split('/').filter(Boolean);
  const ancestors: string[] = [];
  for (let index = 1; index < parts.length; index += 1) {
    ancestors.push(parts.slice(0, index).join('/'));
  }
  return ancestors;
}

function normalizeLookupPath(path: string | null): string | null {
  if (!path) {
    return null;
  }
  const normalized = path.replace(/\\/g, '/').replace(/^\/+|\/+$/g, '').trim();
  if (!normalized) {
    return null;
  }
  return normalized.toLocaleLowerCase();
}

function findNodeByPath(
  entryMap: Map<string, VaultTreeNode>,
  path: string | null,
): VaultTreeNode | null {
  if (!path) {
    return null;
  }

  const exact = entryMap.get(path);
  if (exact) {
    return exact;
  }

  const lookup = normalizeLookupPath(path);
  if (!lookup) {
    return null;
  }

  for (const entry of entryMap.values()) {
    if (normalizeLookupPath(entry.path) === lookup) {
      return entry;
    }
  }

  return null;
}

function getParentPath(path: string): string | null {
  const index = path.lastIndexOf('/');
  return index === -1 ? null : path.slice(0, index);
}

function getLeafName(path: string): string {
  const index = path.lastIndexOf('/');
  return index === -1 ? path : path.slice(index + 1);
}

function remapPath(path: string, fromPath: string, toPath: string): string {
  if (path === fromPath) {
    return toPath;
  }
  if (path.startsWith(`${fromPath}/`)) {
    return `${toPath}${path.slice(fromPath.length)}`;
  }
  return path;
}

function renameEntries(
  entries: VaultTreeEntry[],
  node: VaultTreeNode,
  nextPath: string,
): VaultTreeEntry[] {
  return entries.map((entry) => {
    if (node.kind === 'file' && entry.path !== node.path) {
      return entry;
    }
    if (node.kind === 'folder' && !isVaultPathWithin(entry.path, node.path)) {
      return entry;
    }
    const path = remapPath(entry.path, node.path, nextPath);
    return {
      ...entry,
      path,
      name: getLeafName(path),
      parentPath: getParentPath(path),
    };
  });
}

function joinVaultPath(parentPath: string | null, name: string): string {
  return parentPath ? `${parentPath}/${name}` : name;
}

function sanitizeNodeName(value: string): string | null {
  const next = value.trim();
  if (!next) {
    return null;
  }
  if (/[/\\]/.test(next)) {
    return null;
  }
  return next;
}

function createUniqueName(
  parentPath: string | null,
  preferredName: string,
  existingPaths: Set<string>,
): string {
  const extensionMatch = preferredName.match(/(\.[^.]+)$/);
  const extension = extensionMatch?.[1] ?? '';
  const baseName = extension ? preferredName.slice(0, -extension.length) : preferredName;
  let index = 1;
  let candidate = preferredName;
  while (existingPaths.has(joinVaultPath(parentPath, candidate))) {
    index += 1;
    candidate = `${baseName} ${index}${extension}`;
  }
  return candidate;
}

function syncHintFromStatus(status: VaultSyncStatus): VaultTreeSyncHint | null {
  if (status.phase === 'error') {
    return { tone: 'error', label: '同步失败，后台会重试' };
  }
  if (status.phase === 'offline') {
    return {
      tone: 'offline',
      label: status.pending > 0 ? `离线，${status.pending} 项待同步` : '离线模式',
    };
  }
  if (
    status.phase === 'scanning' ||
    status.phase === 'pushing' ||
    status.phase === 'pulling' ||
    status.phase === 'applying' ||
    status.phase === 'attachments'
  ) {
    return {
      tone: 'syncing',
      label: status.pending > 0 ? `正在同步，剩余 ${status.pending} 项` : '正在同步',
    };
  }
  if (status.pending > 0) {
    return { tone: 'pending', label: `${status.pending} 项待同步` };
  }
  return null;
}

export function isVaultPathWithin(targetPath: string | null, parentPath: string): boolean {
  if (!targetPath) {
    return false;
  }
  return targetPath === parentPath || targetPath.startsWith(`${parentPath}/`);
}

export function useVaultTree(): UseVaultTreeResult {
  const { vaultRoot, status } = useVaultSync();
  const location = useLocation();
  const engine = getVaultEngineSingleton();
  const [tree, setTree] = useState<VaultTreeNode[]>([]);
  const [entryMap, setEntryMap] = useState<Map<string, VaultTreeNode>>(new Map());
  const [loading, setLoading] = useState(false);
  const [expandedPaths, setExpandedPaths] = useState<Set<string>>(new Set());
  const entriesRef = useRef<VaultTreeEntry[]>([]);
  const loadedRootRef = useRef<string | null>(null);

  const applyVaultEntries = useCallback((entries: VaultTreeEntry[]) => {
    entriesRef.current = entries;
    const nextTree = buildVaultTree(entries);
    startTransition(() => {
      setTree(nextTree.tree);
      setEntryMap(nextTree.entryMap);
      setLoading(false);
    });
  }, []);

  const searchParams = useMemo(() => new URLSearchParams(location.search), [location.search]);
  const selectedPath = searchParams.get('path')?.trim() || null;
  const selectedKindParam = searchParams.get('kind');
  const selectedKind: VaultNodeKind | null =
    selectedKindParam === 'file' || selectedKindParam === 'folder'
      ? selectedKindParam
      : selectedPath?.endsWith('.md')
        ? 'file'
        : null;

  const refresh = useCallback(async () => {
    if (!vaultRoot) {
      entriesRef.current = [];
      loadedRootRef.current = null;
      startTransition(() => {
        setTree([]);
        setEntryMap(new Map());
        setLoading(false);
      });
      return;
    }

    const isFirstLoadForRoot = loadedRootRef.current !== vaultRoot;
    if (isFirstLoadForRoot) {
      startTransition(() => {
        setTree([]);
        setEntryMap(new Map());
        setLoading(true);
      });
    }

    try {
      const nextEntries = await listVaultTree(vaultRoot);
      loadedRootRef.current = vaultRoot;
      applyVaultEntries(nextEntries);
    } catch {
      startTransition(() => {
        setLoading(false);
      });
      message.error('读取工作区目录失败');
    }
  }, [applyVaultEntries, vaultRoot]);

  useEffect(() => {
    void refresh();
  }, [refresh, status.lastSyncAt, status.pending, status.phase]);

  useEffect(() => {
    if (!selectedPath) {
      return;
    }
    const resolved = findNodeByPath(entryMap, selectedPath);
    const pathToExpand = resolved?.path ?? selectedPath;
    const ancestors = getAncestors(pathToExpand);
    if (ancestors.length === 0) {
      return;
    }
    setExpandedPaths((current) => {
      const next = new Set(current);
      ancestors.forEach((ancestor) => next.add(ancestor));
      return next;
    });
  }, [entryMap, selectedPath]);

  const selectedNode = useMemo(() => findNodeByPath(entryMap, selectedPath), [entryMap, selectedPath]);
  const existingPaths = useMemo(() => new Set(entriesRef.current.map((entry) => entry.path)), [tree]);
  const syncHint = useMemo(() => syncHintFromStatus(status), [status]);

  const toggleExpanded = useCallback((path: string) => {
    setExpandedPaths((current) => {
      const next = new Set(current);
      const resolvedPath = findNodeByPath(entryMap, path)?.path ?? path;
      if (next.has(resolvedPath)) {
        next.delete(resolvedPath);
      } else {
        next.add(resolvedPath);
      }
      return next;
    });
  }, [entryMap]);

  const setExpanded = useCallback((path: string, expanded: boolean) => {
    setExpandedPaths((current) => {
      const next = new Set(current);
      const resolvedPath = findNodeByPath(entryMap, path)?.path ?? path;
      if (expanded) {
        next.add(resolvedPath);
      } else {
        next.delete(resolvedPath);
      }
      return next;
    });
  }, [entryMap]);

  const createFile = useCallback(
    async (parentPath: string | null) => {
      if (!vaultRoot) {
        return null;
      }
      const fileName = createUniqueName(parentPath, '未命名.md', existingPaths);
      const filePath = joinVaultPath(parentPath, fileName);
      const title = fileName.replace(/\.md$/i, '');
      await engine.onContentChange(filePath, `# ${title}\n`);
      await refresh();
      return filePath;
    },
    [engine, existingPaths, refresh, vaultRoot],
  );

  const createFolder = useCallback(
    async (parentPath: string | null) => {
      if (!vaultRoot) {
        return null;
      }
      const folderName = createUniqueName(parentPath, '未命名文件夹', existingPaths);
      const folderPath = joinVaultPath(parentPath, folderName);
      await createVaultDirectory(vaultRoot, folderPath);
      await refresh();
      return folderPath;
    },
    [existingPaths, refresh, vaultRoot],
  );

  const renameNode = useCallback(
    async (node: VaultTreeNode, nextNameInput: string) => {
      if (!vaultRoot) {
        return null;
      }
      const nextName = sanitizeNodeName(nextNameInput);
      if (!nextName) {
        message.warning('名称不能为空，且不能包含斜杠');
        return null;
      }

      if (node.kind === 'file') {
        const nextFileName = nextName.toLowerCase().endsWith('.md') ? nextName : `${nextName}.md`;
        const nextPath = joinVaultPath(node.parentPath, nextFileName);
        if (nextPath === node.path) {
          return node.path;
        }
        if (existingPaths.has(nextPath)) {
          message.warning('同级已存在同名文件');
          return null;
        }
        const optimisticEntries = renameEntries(entriesRef.current, node, nextPath);
        applyVaultEntries(optimisticEntries);
        try {
          await engine.renameLocalFile(node.path, nextPath);
          await refresh();
        } catch {
          message.error('重命名文件失败，已恢复真实目录状态');
          await refresh();
          return null;
        }
        return nextPath;
      }

      const nextPath = joinVaultPath(node.parentPath, nextName);
      if (nextPath === node.path) {
        return node.path;
      }
      if (existingPaths.has(nextPath)) {
        message.warning('同级已存在同名文件夹');
        return null;
      }

      const descendantFiles = Array.from(entryMap.values())
        .filter((entry) => entry.kind === 'file' && isVaultPathWithin(entry.path, node.path))
        .sort((left, right) => left.path.localeCompare(right.path, 'zh-CN'));
      const fileRenames = descendantFiles.map((file) => ({
        fromPath: file.path,
        toPath: remapPath(file.path, node.path, nextPath),
      }));
      const optimisticEntries = renameEntries(entriesRef.current, node, nextPath);
      applyVaultEntries(optimisticEntries);
      setExpandedPaths((current) => {
        const next = new Set<string>();
        current.forEach((path) => next.add(remapPath(path, node.path, nextPath)));
        return next;
      });
      try {
        await renameVaultDirectory(vaultRoot, node.path, nextPath);
      } catch {
        setExpandedPaths((current) => {
          const next = new Set<string>();
          current.forEach((path) => next.add(remapPath(path, nextPath, node.path)));
          return next;
        });
        message.error('重命名文件夹失败，已恢复真实目录状态');
        await refresh();
        return null;
      }
      void (async () => {
        try {
          for (const file of fileRenames) {
            await engine.recordLocalFileRename(file.fromPath, file.toPath);
          }
        } catch {
          message.error('文件夹已重命名，但同步状态补记失败；后台对账会继续修复');
        } finally {
          await refresh();
        }
      })();
      return nextPath;
    },
    [applyVaultEntries, engine, entryMap, existingPaths, refresh, vaultRoot],
  );

  const deleteNode = useCallback(
    async (node: VaultTreeNode) => {
      if (!vaultRoot) {
        return false;
      }

      if (node.kind === 'file') {
        await engine.deleteLocal(node.path);
        await refresh();
        return true;
      }

      const descendantFiles = Array.from(entryMap.values())
        .filter((entry) => entry.kind === 'file' && isVaultPathWithin(entry.path, node.path))
        .sort((left, right) => left.path.localeCompare(right.path, 'zh-CN'));
      for (const file of descendantFiles) {
        await engine.deleteLocal(file.path);
      }
      await deleteVaultDirectory(vaultRoot, node.path, true);
      await refresh();
      return true;
    },
    [engine, entryMap, refresh, vaultRoot],
  );

  const getFolderChildren = useCallback(
    (path: string | null) => {
      if (!path) {
        return tree;
      }
      return findNodeByPath(entryMap, path)?.children ?? [];
    },
    [entryMap, tree],
  );

  return {
    tree,
    entryMap,
    selectedNode,
    selectedKind,
    selectedPath,
    expandedPaths,
    loading,
    syncHint,
    vaultRoot,
    refresh,
    toggleExpanded,
    setExpanded,
    createFile,
    createFolder,
    renameNode,
    deleteNode,
    getFolderChildren,
  };
}
