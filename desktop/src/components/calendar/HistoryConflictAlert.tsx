import { Alert, Button, Space } from 'antd';
import type { HistoryDayStatus } from '../../services/vault/historyReconcile';

interface HistoryConflictAlertProps {
  status: Exclude<HistoryDayStatus, 'empty' | 'in_sync'>;
  date: string;
  busy: boolean;
  onResolve: (action: 'keep_sql' | 'keep_md' | 'regenerate' | 'import') => void;
}

/**
 * 历史日期对账状态提示（docs/09 §8.2 五状态中需用户介入的三种）。
 * - conflict：Notes/Daily/<date>.md 与沉淀记录不一致（外部/Obsidian 改过）→ 整单拍板
 * - md_missing：沉淀过但 .md 被删 → 从记录重新生成
 * - external_only：无沉淀记录但有外部 .md → 导入到记录
 * in_sync / empty 不显示本组件。
 */
export function HistoryConflictAlert({ status, date, busy, onResolve }: HistoryConflictAlertProps) {
  if (status === 'conflict') {
    return (
      <Alert
        type="warning"
        showIcon
        message={`Notes/Daily/${date}.md 与记录不一致`}
        description="检测到沉淀文件被外部编辑（如在 Obsidian 中修改）。请选择以哪一边为准同步："
        action={
          <Space>
            <Button size="small" loading={busy} onClick={() => onResolve('keep_sql')}>
              以记录为准（重生成文件）
            </Button>
            <Button size="small" loading={busy} onClick={() => onResolve('keep_md')}>
              以文件为准（回写记录）
            </Button>
          </Space>
        }
      />
    );
  }

  if (status === 'md_missing') {
    return (
      <Alert
        type="info"
        showIcon
        message={`沉淀文件缺失（Notes/Daily/${date}.md）`}
        description="该日期已沉淀，但文件被删除或丢失。可从记录重新生成。"
        action={
          <Button size="small" type="primary" loading={busy} onClick={() => onResolve('regenerate')}>
            从记录重新生成
          </Button>
        }
      />
    );
  }

  // external_only
  return (
    <Alert
      type="info"
      showIcon
      message={`检测到外部文件（Notes/Daily/${date}.md）`}
      description="该日期无沉淀记录，但存在外部文件。可导入到记录以便统一管理。"
      action={
        <Button size="small" type="primary" loading={busy} onClick={() => onResolve('import')}>
          导入到记录
        </Button>
      }
    />
  );
}
