import { useEffect } from 'react';
import { Button } from 'antd';
import { FolderOpenOutlined } from '@ant-design/icons';
import { isTauriRuntime } from '../../services/vault';

/**
 * 工作区门面：未选择 vault 根目录时全屏引导用户选择文件夹（本地优先的事实来源）。
 * 非 Tauri（浏览器/mock 预览）挂载即自动取内存根，零交互；Tauri 桌面端弹原生选择器。
 */
export function WorkspaceGate({ onChoose }: { onChoose: () => Promise<void> | void }) {
  useEffect(() => {
    if (!isTauriRuntime()) {
      // 浏览器/mock 预览：直接用内存根，避免阻塞
      void onChoose();
    }
  }, [onChoose]);

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        background: '#f5f7fb',
        padding: 24,
      }}
    >
      <div
        style={{
          maxWidth: 480,
          textAlign: 'center',
          background: '#fff',
          borderRadius: 16,
          boxShadow: '0 10px 40px rgba(15, 23, 42, 0.08)',
          padding: '40px 32px',
        }}
      >
        <FolderOpenOutlined style={{ fontSize: 48, color: '#3b82f6', marginBottom: 16 }} />
        <h2 style={{ margin: '0 0 8px', fontSize: 22 }}>选择工作区文件夹</h2>
        <p style={{ color: '#64748b', lineHeight: 1.7, marginBottom: 24 }}>
          LifeScale 把你的今日记录、日程、复盘以 Markdown 文件存在本地。请选择一个文件夹作为工作区（随时可在「设置」中更改）。
        </p>
        <Button
          type="primary"
          size="large"
          icon={<FolderOpenOutlined />}
          onClick={() => void onChoose()}
        >
          选择文件夹
        </Button>
        <p style={{ color: '#94a3b8', fontSize: 12, marginTop: 24, marginBottom: 0 }}>
          不登录也能完整使用本地数据；登录后再开启云同步。
        </p>
      </div>
    </div>
  );
}
