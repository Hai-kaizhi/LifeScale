import { Alert, Button, Modal, Space, Tag } from 'antd';
import { CloudDownloadOutlined, CloudUploadOutlined, ExclamationCircleOutlined } from '@ant-design/icons';
import type { WorkspaceSyncPreview } from '../../shared/types/vault';

interface WorkspaceSyncPreviewModalProps {
  preview: WorkspaceSyncPreview | null;
  open: boolean;
  title?: string;
  confirmLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

const METRIC_COLORS = {
  neutral: '#475569',
  upload: '#2563eb',
  download: '#059669',
  conflict: '#dc2626',
  deleted: '#d97706',
} as const;

function MetricCard({
  label,
  value,
  color = METRIC_COLORS.neutral,
}: {
  label: string;
  value: number;
  color?: string;
}) {
  return (
    <div
      style={{
        border: '1px solid #e2e8f0',
        borderRadius: 14,
        padding: '12px 14px',
        background: '#fff',
      }}
    >
      <div style={{ color: '#64748b', fontSize: 12, marginBottom: 6 }}>{label}</div>
      <div style={{ color, fontSize: 24, fontWeight: 700, lineHeight: 1 }}>{value}</div>
    </div>
  );
}

export function WorkspaceSyncPreviewModal({
  preview,
  open,
  title = '同步预检',
  confirmLoading = false,
  onConfirm,
  onCancel,
}: WorkspaceSyncPreviewModalProps) {
  const hasConflict = Boolean(preview && preview.conflictFiles > 0);
  const hasRemote = Boolean(preview && preview.remoteFiles > 0);
  const emptyLocal = Boolean(preview && preview.localFiles === 0);
  const description = emptyLocal && hasRemote
    ? '当前文件夹为空，将作为本账号云空间的本地镜像目录，先拉取云端 Markdown。'
    : '系统会按路径与内容 hash 安全合并；同路径不同内容会进入冲突列表，不会覆盖任意一方。';

  return (
    <Modal
      open={open}
      centered
      width={620}
      title={title}
      closable={!confirmLoading}
      maskClosable={!confirmLoading}
      onCancel={confirmLoading ? undefined : onCancel}
      footer={[
        <Button key="later" onClick={onCancel} disabled={confirmLoading}>
          稍后
        </Button>,
        <Button key="sync" type="primary" loading={confirmLoading} onClick={onConfirm}>
          开始同步
        </Button>,
      ]}
    >
      {!preview ? null : (
        <div style={{ display: 'grid', gap: 16 }}>
          <Alert
            type={preview.failed ? 'error' : hasConflict ? 'warning' : 'info'}
            showIcon
            message={preview.failed ? '工作区预检失败' : '本次同步不会覆盖本地 Markdown'}
            description={preview.message ?? description}
          />

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
              gap: 10,
            }}
          >
            <MetricCard label="本地 Markdown" value={preview.localFiles} />
            <MetricCard label="云端 Markdown" value={preview.remoteFiles} />
            <MetricCard label="内容相同" value={preview.sameFiles} />
            <MetricCard label="需上传" value={preview.uploadFiles} color={METRIC_COLORS.upload} />
            <MetricCard label="需下载" value={preview.downloadFiles} color={METRIC_COLORS.download} />
            <MetricCard label="同路径冲突" value={preview.conflictFiles} color={METRIC_COLORS.conflict} />
            <MetricCard label="远端墓碑" value={preview.remoteDeletedFiles} color={METRIC_COLORS.deleted} />
            <MetricCard label="本地待删除" value={preview.deletedFiles} color={METRIC_COLORS.deleted} />
            <MetricCard label="附件待上传" value={preview.pendingAttachments} color={METRIC_COLORS.upload} />
          </div>

          <Space wrap size={[8, 8]}>
            <Tag icon={<CloudUploadOutlined />} color="blue">
              待上传 {preview.uploadFiles + preview.dirtyFiles + preview.pendingFiles}
            </Tag>
            <Tag icon={<CloudDownloadOutlined />} color="green">
              待拉取 {preview.downloadFiles}
            </Tag>
            <Tag icon={<ExclamationCircleOutlined />} color={hasConflict ? 'red' : 'default'}>
              冲突 {preview.conflictFiles}
            </Tag>
          </Space>
        </div>
      )}
    </Modal>
  );
}
