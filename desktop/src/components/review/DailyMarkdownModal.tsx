import { Alert, Button, Empty, Input, Modal, Spin, Tabs } from 'antd';
import type { ReactNode } from 'react';
import { useEffect, useMemo, useState } from 'react';
import type { DailyMarkdownDocument } from '../../shared/types/dailyMarkdown';

interface DailyMarkdownModalProps {
  open: boolean;
  document: DailyMarkdownDocument | null;
  loading: boolean;
  saving: boolean;
  error: string | null;
  onClose: () => void;
  onSaveSource: (content: string) => Promise<DailyMarkdownDocument | null>;
}

function renderInlineText(text: string): string {
  return text.trim();
}

function renderMarkdownPreview(content: string): ReactNode {
  if (!content.trim()) {
    return (
      <Empty
        image={Empty.PRESENTED_IMAGE_SIMPLE}
        description="暂无 Markdown 内容"
        className="daily-markdown-empty"
      />
    );
  }

  const nodes: ReactNode[] = [];
  let listItems: ReactNode[] = [];
  let listType: 'task' | 'bullet' | null = null;

  const flushList = () => {
    if (!listItems.length || !listType) {
      return;
    }
    const className =
      listType === 'task' ? 'daily-markdown-task-list' : 'daily-markdown-bullet-list';
    nodes.push(
      <ul className={className} key={`list-${nodes.length}`}>
        {listItems}
      </ul>,
    );
    listItems = [];
    listType = null;
  };

  content.split('\n').forEach((rawLine, index) => {
    const line = rawLine.trim();
    if (!line) {
      flushList();
      return;
    }

    const taskMatch = line.match(/^- \[(x|X| )\]\s+(.+)$/);
    if (taskMatch) {
      if (listType !== 'task') {
        flushList();
        listType = 'task';
      }
      const checked = taskMatch[1].toLowerCase() === 'x';
      listItems.push(
        <li className={checked ? 'is-checked' : undefined} key={`task-${index}`}>
          <input type="checkbox" checked={checked} readOnly aria-label={checked ? '已完成' : '未完成'} />
          <span>{renderInlineText(taskMatch[2])}</span>
        </li>,
      );
      return;
    }

    const bulletMatch = line.match(/^- (.+)$/);
    if (bulletMatch) {
      if (listType !== 'bullet') {
        flushList();
        listType = 'bullet';
      }
      listItems.push(<li key={`bullet-${index}`}>{renderInlineText(bulletMatch[1])}</li>);
      return;
    }

    flushList();
    if (line.startsWith('### ')) {
      nodes.push(<h3 key={`h3-${index}`}>{renderInlineText(line.slice(4))}</h3>);
      return;
    }
    if (line.startsWith('## ')) {
      nodes.push(<h2 key={`h2-${index}`}>{renderInlineText(line.slice(3))}</h2>);
      return;
    }
    if (line.startsWith('# ')) {
      nodes.push(<h1 key={`h1-${index}`}>{renderInlineText(line.slice(2))}</h1>);
      return;
    }

    nodes.push(<p key={`p-${index}`}>{renderInlineText(line)}</p>);
  });

  flushList();
  return nodes;
}

export function DailyMarkdownModal({
  open,
  document,
  loading,
  saving,
  error,
  onClose,
  onSaveSource,
}: DailyMarkdownModalProps) {
  const [source, setSource] = useState('');
  const [activeTab, setActiveTab] = useState('preview');

  useEffect(() => {
    if (!open) {
      return;
    }
    setSource(document?.content ?? '');
    setActiveTab('preview');
  }, [document?.content, document?.date, open]);

  const canSaveSource = Boolean(document?.permissions.canEdit && document.permissions.canSave);
  const hasChanges = source !== (document?.content ?? '');

  const preview = useMemo(() => renderMarkdownPreview(source), [source]);

  const handleSave = async () => {
    if (!document) {
      return;
    }
    const saved = await onSaveSource(source);
    if (saved) {
      setSource(saved.content);
    }
  };

  return (
    <Modal
      title={
        <div className="daily-markdown-modal-title">
          <strong>查看 Markdown</strong>
          <span>{document?.relativePath ?? 'Daily/YYYY-MM-DD.md'}</span>
        </div>
      }
      open={open}
      onCancel={onClose}
      width={920}
      centered
      className="daily-markdown-modal"
      footer={[
        <Button key="close" onClick={onClose}>
          关闭
        </Button>,
        <Button
          key="save"
          type="primary"
          loading={saving}
          disabled={!document || !canSaveSource || !hasChanges}
          onClick={() => void handleSave()}
        >
          保存源码
        </Button>,
      ]}
    >
      {loading ? (
        <div className="daily-markdown-loading">
          <Spin />
          <span>正在加载 Markdown 文档...</span>
        </div>
      ) : (
        <>
          {error && (
            <Alert
              type="error"
              showIcon
              className="daily-markdown-alert"
              message="Markdown 文档加载失败"
              description={error}
            />
          )}

          {document?.absolutePath && (
            <div className="daily-markdown-path">
              <span>保存路径</span>
              <strong>{document.absolutePath}</strong>
            </div>
          )}

          {!canSaveSource && document?.permissions.reason && (
            <Alert
              type={document.permissions.canView ? 'warning' : 'error'}
              showIcon
              className="daily-markdown-alert"
              message={document.permissions.reason}
            />
          )}

          <Tabs
            activeKey={activeTab}
            onChange={setActiveTab}
            items={[
              {
                key: 'preview',
                label: '渲染预览',
                children: (
                  <article className="daily-markdown-preview">
                    {preview}
                  </article>
                ),
              },
              {
                key: 'source',
                label: 'Markdown 源码',
                children: (
                  <div className="daily-markdown-source-wrap">
                    <Input.TextArea
                      value={source}
                      disabled={!canSaveSource || saving}
                      autoSize={{ minRows: 18, maxRows: 28 }}
                      className="daily-markdown-source"
                      onChange={(event) => setSource(event.target.value)}
                    />
                  </div>
                ),
              },
            ]}
          />
        </>
      )}
    </Modal>
  );
}
