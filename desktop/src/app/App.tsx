import { Suspense, lazy } from 'react';
import { createHashRouter, RouterProvider, Navigate } from 'react-router';
import { ConfigProvider } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import { AuthProvider, useAuth } from '../hooks/useAuth';
import { VaultSyncProvider } from '../hooks/useVaultSync';
import { SettingsModalProvider } from '../hooks/useSettingsModal';
import { VaultSyncBadge } from '../components/vault/VaultSyncBadge';
import { CurrentDateProvider } from '../contexts/CurrentDateContext';
import { AppLayout } from '../components/layout/AppLayout';
import { TodayPage } from '../pages/TodayPage';
import { ReviewPage } from '../pages/ReviewPage';
import { CalendarReviewPage } from '../pages/CalendarReviewPage';
import { SearchPage } from '../pages/SearchPage';
import { ROUTES } from '../shared/constants';
import './App.css';

const VaultNotesPage = lazy(() =>
  import('../pages/VaultNotesPage').then((module) => ({ default: module.VaultNotesPage })),
);

function RouteFallback() {
  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '50vh', color: '#64748b' }}>
      正在加载页面...
    </div>
  );
}

const router = createHashRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <Navigate to={ROUTES.TODAY} replace /> },
      { path: 'today', element: <TodayPage /> },
      { path: 'calendar', element: <CalendarReviewPage /> },
      {
        path: 'vault',
        element: (
          <Suspense fallback={<RouteFallback />}>
            <VaultNotesPage />
          </Suspense>
        ),
      },
      { path: 'search', element: <SearchPage /> },
      { path: 'review', element: <ReviewPage /> },
      { path: '*', element: <Navigate to={ROUTES.TODAY} replace /> },
    ],
  },
]);

/**
 * 鉴权门面：loading 时占位；其余状态（local 未登录 / authenticated 已登录）均进主路由。
 * 本地优先：未登录即 `local` 态进入应用；VaultSyncProvider 内部按 vaultRoot 显示工作区门面、
 * 按 authStatus 开关云同步。登录入口在「个人设置」内。
 */
function AppGate() {
  const { status } = useAuth();
  if (status === 'loading') {
    return (
      <div style={{ display: 'grid', placeItems: 'center', minHeight: '100vh', color: '#64748b' }}>
        加载中...
      </div>
    );
  }
  return (
    <VaultSyncProvider>
      <SettingsModalProvider>
        <VaultSyncBadge />
        <RouterProvider router={router} />
      </SettingsModalProvider>
    </VaultSyncProvider>
  );
}

export default function App() {
  return (
    <ConfigProvider locale={zhCN}>
      <AuthProvider>
        <CurrentDateProvider>
          <AppGate />
        </CurrentDateProvider>
      </AuthProvider>
    </ConfigProvider>
  );
}
