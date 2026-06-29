import { useLocation, useNavigate } from 'react-router';
import { Avatar } from 'antd';
import type { CSSProperties, ReactNode } from 'react';
import {
  CalendarOutlined,
  CheckSquareOutlined,
  DownOutlined,
  FileTextOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  PieChartOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { useCallback } from 'react';
import { useSettingsModal } from '../../hooks/useSettingsModal';
import { isVaultPathWithin, useVaultTree, type VaultTreeNode } from '../../hooks/useVaultTree';
import { useUserProfile } from '../../hooks/useUserProfile';
import { ROUTES } from '../../shared/constants';
import { buildVaultRoute } from '../../shared/utils/vaultRoute';
import { VaultTreePanel } from '../vault/VaultTreePanel';
import './Sidebar.css';

interface NavItem {
  key: string;
  label: string;
  icon: ReactNode;
  path: string;
}

const NAV_ITEMS: NavItem[] = [
  { key: 'today', label: '今日', icon: <CheckSquareOutlined />, path: '/today' },
  { key: 'calendar', label: '日历', icon: <CalendarOutlined />, path: '/calendar' },
  { key: 'review', label: '复盘', icon: <PieChartOutlined />, path: '/review' },
];

interface SidebarProps {
  collapsed: boolean;
  effectiveWidth: number;
  onToggleCollapse: () => void;
}

/**
 * 侧栏：主导航 + 本地工作区笔记树 + 用户/折叠。
 */
export function Sidebar({ collapsed, effectiveWidth, onToggleCollapse }: SidebarProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const { openSettingsModal } = useSettingsModal();
  const currentPath = location.pathname;
  const { profile, isAuthenticated } = useUserProfile();
  const {
    tree,
    loading,
    syncHint,
    selectedPath,
    selectedKind,
    expandedPaths,
    setExpanded,
    toggleExpanded,
    createFile,
    createFolder,
    renameNode,
    deleteNode,
  } = useVaultTree();

  // 宽度由 AppLayout 计算后注入；窄屏媒体查询会覆盖为 100%（顶部栏布局）
  const asideStyle = { '--sidebar-width': `${effectiveWidth}px` } as CSSProperties;

  // 已登录显示昵称；未登录统一显示「未登录」，不再使用硬编码占位名。
  const displayName = isAuthenticated && profile.nickname.trim() ? profile.nickname : '未登录';

  const handleOpenNode = useCallback(
    (node: VaultTreeNode) => {
      if (node.kind === 'folder') {
        setExpanded(node.path, true);
      }
      navigate(buildVaultRoute(node.path, node.kind));
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

      if (currentPath === ROUTES.VAULT && selectedPath) {
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
    [currentPath, navigate, renameNode, selectedKind, selectedPath],
  );

  const handleDeleteNode = useCallback(
    async (node: VaultTreeNode) => {
      await deleteNode(node);
      if (currentPath === ROUTES.VAULT && selectedPath) {
        const deletingCurrent =
          selectedPath === node.path || (node.kind === 'folder' && isVaultPathWithin(selectedPath, node.path));
        if (deletingCurrent) {
          navigate(node.parentPath ? buildVaultRoute(node.parentPath, 'folder') : ROUTES.VAULT, {
            replace: true,
          });
        }
      }
    },
    [currentPath, deleteNode, navigate, selectedPath],
  );

  return (
    <aside className={`sidebar${collapsed ? ' is-collapsed' : ''}`} style={asideStyle}>
      <div className="sidebar-brand">
        <div className="sidebar-brand-icon">
          <FileTextOutlined />
        </div>
        <div className="sidebar-brand-copy">
          <span className="sidebar-brand-title">人生刻度</span>
          <span className="sidebar-brand-subtitle">MyToday</span>
        </div>
      </div>

      <nav className="sidebar-nav" aria-label="主导航">
        {NAV_ITEMS.map((item) => {
          const isActive = currentPath === item.path || currentPath.startsWith(`${item.path}/`);
          return (
            <button
              key={item.key}
              type="button"
              className={`sidebar-nav-item${isActive ? ' active' : ''}`}
              onClick={() => navigate(item.path)}
              title={collapsed ? item.label : undefined}
              aria-label={item.label}
            >
              <span className="sidebar-nav-icon">{item.icon}</span>
              <span className="sidebar-nav-label">{item.label}</span>
            </button>
          );
        })}
      </nav>

      <section className="sidebar-kb-panel" aria-label="Vault 笔记">
        <div className="sidebar-kb">
          <VaultTreePanel
            title="笔记"
            tree={tree}
            loading={loading}
            syncHint={syncHint}
            selectedPath={currentPath === ROUTES.VAULT ? selectedPath : null}
            selectedKind={currentPath === ROUTES.VAULT ? selectedKind : null}
            expandedPaths={expandedPaths}
            onOpenNode={handleOpenNode}
            onToggleExpanded={toggleExpanded}
            onCreateFile={handleCreateFile}
            onCreateFolder={handleCreateFolder}
            onRenameNode={handleRenameNode}
            onDeleteNode={handleDeleteNode}
          />
        </div>
      </section>

      <div className="sidebar-footer">
        <button
          type="button"
          className={`sidebar-user${isAuthenticated ? '' : ' is-guest'}`}
          onClick={() => openSettingsModal('profile')}
          aria-label="打开个人设置"
          title={collapsed ? '打开个人设置' : undefined}
        >
          {isAuthenticated ? (
            <Avatar
              size={48}
              src={profile.avatarUrl || undefined}
              className="sidebar-user-avatar"
            >
              {displayName.charAt(0)}
            </Avatar>
          ) : (
            <Avatar size={48} icon={<UserOutlined />} className="sidebar-user-avatar is-guest" />
          )}
          <span className="sidebar-user-name">{displayName}</span>
          <DownOutlined className="sidebar-user-arrow" />
        </button>
      </div>
      <button
        type="button"
        className="sidebar-collapse-btn"
        onClick={onToggleCollapse}
        aria-label={collapsed ? '展开侧边栏' : '收起侧边栏'}
        title={collapsed ? '展开侧边栏' : '收起侧边栏'}
      >
        {collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
        <span className="sidebar-collapse-label">收起菜单</span>
      </button>
    </aside>
  );
}
