import { Badge, Button, Space, Tooltip, Typography } from 'antd';
import {
  CheckCircleOutlined,
  CloudSyncOutlined,
  DisconnectOutlined,
  FolderOpenOutlined,
  LoadingOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import { useVaultSync } from '../../hooks/useVaultSync';
import { useAuth } from '../../hooks/useAuth';

/**
 * Vault 同步状态徽标（固定在右上角）：同步中/已同步/离线/待同步 N/冲突 N。
 * 未配置同步文件夹时显示「选择同步文件夹」入口。
 */
export function VaultSyncBadge() {
  const { status, vaultRoot, chooseVaultFolder } = useVaultSync();
  const { status: authStatus } = useAuth();

  if (!vaultRoot) {
    return (
      <div style={{ position: 'fixed', right: 16, top: 12, zIndex: 1000 }}>
        <Button size="small" icon={<CloudSyncOutlined />} onClick={() => void chooseVaultFolder()}>
          选择同步文件夹
        </Button>
      </div>
    );
  }

  let icon = <LoadingOutlined />;
  let color: 'processing' | 'success' | 'default' | 'warning' | 'error' = 'processing';
  let text = '同步中';
  if (authStatus !== 'authenticated') {
    icon = <FolderOpenOutlined />;
    color = 'default';
    text = '本地模式';
  } else if (!status.online) {
    icon = <DisconnectOutlined />;
    color = 'default';
    text = '离线';
  } else if (status.conflict > 0) {
    icon = <WarningOutlined />;
    color = 'error';
    text = `${status.conflict} 冲突`;
  } else if (status.pending > 0) {
    icon = <CloudSyncOutlined />;
    color = 'warning';
    text = `${status.pending} 待同步`;
  } else if (status.phase === 'synced') {
    icon = <CheckCircleOutlined />;
    color = 'success';
    text = '已同步';
  }

  return (
    <div style={{ position: 'fixed', right: 16, top: 12, zIndex: 1000 }}>
      <Tooltip
        title={
          <Space direction="vertical" size={0}>
            <span>Vault 同步</span>
            <span>状态：{status.phase}</span>
            {status.lastSyncAt && <span>最近同步：{new Date(status.lastSyncAt).toLocaleString()}</span>}
          </Space>
        }
      >
        <Badge status={color} offset={[-2, 2]}>
          <Typography.Text style={{ fontSize: 12 }}>
            <Space size={4}>
              {icon}
              {text}
            </Space>
          </Typography.Text>
        </Badge>
      </Tooltip>
    </div>
  );
}
