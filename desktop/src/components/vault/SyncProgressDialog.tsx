import { Button, Modal, Progress } from 'antd';
import { CheckCircleFilled, CloudSyncOutlined, ExclamationCircleFilled } from '@ant-design/icons';
import type { InitialSyncProgress } from '../../hooks/useVaultSync';

interface SyncProgressDialogProps {
  sync: InitialSyncProgress | null;
  onClose: () => void;
}

const PHASE_TEXT: Record<string, string> = {
  scanning: '正在扫描本地与云端差异…',
  pushing: '正在上传本地修改…',
  pulling: '正在拉取云端笔记…',
  applying: '正在应用本地文件变更…',
  attachments: '正在同步图片附件…',
  synced: '本地与云端已一致',
  error: '同步失败，将在后台自动重试',
  offline: '当前离线，将在联网后继续',
  idle: '准备同步…',
};

/**
 * 前台同步进度弹窗：登录后 / 选择工作区文件夹后触发，显示「已同步 X / Y 篇笔记」+ 进度条。
 * 仅当有可同步内容（total>0）时显示；完成/失败可手动关闭，进行中可「后台同步」（同步不受影响）。
 */
export function SyncProgressDialog({ sync, onClose }: SyncProgressDialogProps) {
  if (!sync) return null;
  const total = sync.total;
  const open = sync.phase !== 'idle' || total > 0;
  const done = Math.min(sync.done, total);
  const percent = total > 0 ? Math.round((done / total) * 100) : sync.phase === 'synced' ? 100 : 12;
  const isDone = sync.phase === 'synced';
  const isError = sync.phase === 'error';
  const busy = !isDone && !isError;
  const status: 'active' | 'success' | 'exception' | 'normal' = isError
    ? 'exception'
    : isDone
      ? 'success'
      : 'active';

  return (
    <Modal
      open={open}
      centered
      closable={false}
      maskClosable={false}
      keyboard={false}
      width={420}
      footer={
        busy
          ? [
              <Button key="background" type="link" onClick={onClose}>
                后台同步
              </Button>,
            ]
          : [
              <Button key="ok" type="primary" onClick={onClose}>
                {isError ? '知道了' : '完成'}
              </Button>,
            ]
      }
    >
      <div style={{ textAlign: 'center', padding: '8px 0 4px' }}>
        {isDone ? (
          <CheckCircleFilled style={{ fontSize: 44, color: '#22c55e' }} />
        ) : isError ? (
          <ExclamationCircleFilled style={{ fontSize: 44, color: '#ef4444' }} />
        ) : (
          <CloudSyncOutlined spin style={{ fontSize: 44, color: '#3b82f6' }} />
        )}
        <h3 style={{ margin: '16px 0 4px', fontSize: 18 }}>
          {isDone ? '同步完成' : isError ? '同步出现问题' : '同步任务中心'}
        </h3>
        <p style={{ color: '#64748b', margin: 0, minHeight: 22 }}>
          {sync.message ?? PHASE_TEXT[sync.phase] ?? ''}
        </p>

        <Progress percent={percent} status={status} style={{ maxWidth: 320, margin: '18px auto 8px' }} />

        <p style={{ color: '#94a3b8', fontSize: 13, margin: 0 }}>
          已处理 <strong style={{ color: '#334155' }}>{done}</strong> / {total} 项任务
        </p>
      </div>
    </Modal>
  );
}
