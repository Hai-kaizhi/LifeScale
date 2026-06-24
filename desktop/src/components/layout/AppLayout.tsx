import { useCallback, useEffect, useRef, useState } from 'react';
import type { MouseEvent as ReactMouseEvent } from 'react';
import { Outlet } from 'react-router';
import { Sidebar } from './Sidebar';
import './AppLayout.css';

const SIDEBAR_STORAGE_KEY = 'lifescale.sidebar.state.v1';
const SIDEBAR_COLLAPSED_WIDTH = 72;
const SIDEBAR_MIN_WIDTH = 220;
const SIDEBAR_MAX_WIDTH = 440;
const SIDEBAR_DEFAULT_WIDTH = 270;

interface SidebarState {
  collapsed: boolean;
  width: number;
}

function clampWidth(value: number): number {
  return Math.min(SIDEBAR_MAX_WIDTH, Math.max(SIDEBAR_MIN_WIDTH, value));
}

function loadSidebarState(): SidebarState {
  if (typeof window === 'undefined') {
    return { collapsed: false, width: SIDEBAR_DEFAULT_WIDTH };
  }
  try {
    const raw = window.localStorage.getItem(SIDEBAR_STORAGE_KEY);
    if (!raw) return { collapsed: false, width: SIDEBAR_DEFAULT_WIDTH };
    const parsed = JSON.parse(raw) as Partial<SidebarState>;
    return {
      collapsed: Boolean(parsed.collapsed),
      width: parsed.width ? clampWidth(parsed.width) : SIDEBAR_DEFAULT_WIDTH,
    };
  } catch {
    return { collapsed: false, width: SIDEBAR_DEFAULT_WIDTH };
  }
}

function persistSidebarState(state: SidebarState): void {
  try {
    window.localStorage.setItem(SIDEBAR_STORAGE_KEY, JSON.stringify(state));
  } catch {
    // 忽略持久化失败（隐私模式 / 存储不可用）
  }
}

export function AppLayout() {
  const [sidebarState, setSidebarState] = useState<SidebarState>(loadSidebarState);
  const draggingRef = useRef(false);

  const { collapsed, width } = sidebarState;
  // 折叠时固定为窄图标条宽度，展开时使用用户拖拽/记忆的宽度
  const effectiveWidth = collapsed ? SIDEBAR_COLLAPSED_WIDTH : width;

  // 折叠/展开 或 拖拽改宽 后，把状态写回本地存储
  useEffect(() => {
    persistSidebarState({ collapsed, width });
  }, [collapsed, width]);

  const toggleCollapse = useCallback(() => {
    setSidebarState((prev) => ({ ...prev, collapsed: !prev.collapsed }));
  }, []);

  const handleResizeStart = useCallback(
    (event: ReactMouseEvent<HTMLDivElement>) => {
      if (collapsed) return;
      event.preventDefault();
      draggingRef.current = true;
      document.body.style.userSelect = 'none';
      document.body.style.cursor = 'col-resize';

      const onMove = (ev: MouseEvent) => {
        if (!draggingRef.current) return;
        // 侧边栏左边缘贴合视口左侧，故光标横坐标即新的侧边栏宽度
        const next = clampWidth(ev.clientX);
        setSidebarState((prev) => (prev.collapsed ? prev : { ...prev, width: next }));
      };
      const onUp = () => {
        draggingRef.current = false;
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      };

      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    },
    [collapsed],
  );

  const resetWidth = useCallback(() => {
    if (collapsed) return;
    setSidebarState((prev) => ({ ...prev, width: SIDEBAR_DEFAULT_WIDTH }));
  }, [collapsed]);

  return (
    <div className="app-layout">
      <Sidebar
        collapsed={collapsed}
        effectiveWidth={effectiveWidth}
        onToggleCollapse={toggleCollapse}
      />
      <div
        className={`sidebar-resizer${collapsed ? ' is-disabled' : ''}`}
        role="separator"
        aria-orientation="vertical"
        aria-label="拖动调整侧边栏宽度，双击恢复默认宽度"
        onMouseDown={handleResizeStart}
        onDoubleClick={resetWidth}
      />
      <main className="app-layout-main">
        <Outlet />
      </main>
    </div>
  );
}
