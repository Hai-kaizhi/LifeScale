import { Modal, Tabs, Typography, Space, Tag, Alert } from 'antd';
import type { ConflictEvent } from '../../services/vault';

interface Props {
  conflict: ConflictEvent;
  onKeepMine: () => void;
  onKeepTheirs: () => void;
}

/**
 * 冲突解决弹窗：并排展示「本地(mine) / 云端(theirs)」，提供保留本地 / 保留云端。
 * 双方内容都已安全保留（云端 theirs 在正本、mine 推送后成正本，且服务端已生成 .conflict 副本）。
 */
export function ConflictResolutionModal({ conflict, onKeepMine, onKeepTheirs }: Props) {
  const { vaultPath, mineContent, conflict: view } = conflict;
  return (
    <Modal
      open
      title={`同步冲突：${vaultPath}`}
      onCancel={onKeepTheirs}
      footer={
        <Space>
          <Tag color="default">冲突副本：{view.conflictCopyPath}</Tag>
          <button className="ant-btn ant-btn-default" onClick={onKeepTheirs}>
            保留云端
          </button>
          <button className="ant-btn ant-btn-primary" onClick={onKeepMine}>
            保留本地
          </button>
        </Space>
      }
      width={760}
      destroyOnClose
    >
      <Alert
        type="warning"
        showIcon
        style={{ marginBottom: 12 }}
        message="两端都改了这份文件，已自动生成冲突副本，不会丢失任何一方内容。请选择保留哪一份。"
      />
      <Tabs
        items={[
          {
            key: 'mine',
            label: '本地（我的）',
            children: (
              <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', maxHeight: 360, overflow: 'auto', margin: 0 }}>
                {mineContent || '(空)'}
              </pre>
            ),
          },
          {
            key: 'theirs',
            label: '云端（服务端）',
            children: (
              <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', maxHeight: 360, overflow: 'auto', margin: 0 }}>
                {view.theirsContent || '(空)'}
              </pre>
            ),
          },
        ]}
      />
      <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
        未选一方也可稍后处理：冲突副本文件（.conflict-*.md）保留了两份内容的差异标记。
      </Typography.Paragraph>
    </Modal>
  );
}
