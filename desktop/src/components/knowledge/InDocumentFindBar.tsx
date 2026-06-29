import { Button, Input, Tooltip } from 'antd';
import {
  CloseOutlined,
  DownOutlined,
  UpOutlined,
} from '@ant-design/icons';
import { useEffect, useRef, useState } from 'react';
import type { ToastMarkdownEditorHandle } from './ToastMarkdownEditor';

interface InDocumentFindBarProps {
  open: boolean;
  onClose: () => void;
  editorRef: React.RefObject<ToastMarkdownEditorHandle | null>;
}

/**
 * 文档内查找栏（Ctrl+F）。
 *
 * 本组件只负责 UI（输入框、上/下一个、计数、大小写切换、关闭），
 * 所有匹配高亮、跳转、计数都委托给编辑器内部由 prosemirror-search 驱动的能力：
 * - 高亮：编辑器注入的 search() 插件通过 Decoration 直接渲染在内容 DOM 上，无坐标偏移。
 * - 跳转/计数：通过 editorRef 调用 findNext / findPrev / getMatchCount。
 *
 * 关键词或大小写变化时调用 setSearchKeyword 更新插件查询词，高亮自动重算。
 */
export function InDocumentFindBar({ open, onClose, editorRef }: InDocumentFindBarProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [keyword, setKeyword] = useState('');
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [matchCount, setMatchCount] = useState(0);
  const [activeIndex, setActiveIndex] = useState(0);

  // 打开时自动聚焦输入框。
  useEffect(() => {
    if (open) {
      const timer = window.setTimeout(() => inputRef.current?.focus(), 0);
      return () => window.clearTimeout(timer);
    }
    // 关闭时清除搜索高亮。
    editorRef.current?.clearSearch();
    setKeyword('');
    setMatchCount(0);
    setActiveIndex(0);
  }, [open, editorRef]);

  // 关键词 / 大小写变化 → 更新查询词并刷新计数。
  useEffect(() => {
    if (!open) {
      return;
    }
    const handle = editorRef.current;
    if (!handle) {
      return;
    }
    if (!keyword) {
      handle.clearSearch();
      setMatchCount(0);
      setActiveIndex(0);
      return;
    }
    handle.setSearchKeyword(keyword, caseSensitive);
    // prosemirror-search 的 query 更新后立即读取高亮计数。
    const count = handle.getMatchCount();
    setMatchCount(count);
    setActiveIndex(count > 0 ? 1 : 0);
  }, [open, keyword, caseSensitive, editorRef]);

  const handleFindNext = () => {
    editorRef.current?.findNext();
    // 跳转后当前序号 +1（循环）。
    if (matchCount > 0) {
      setActiveIndex((prev) => (prev >= matchCount ? 1 : prev + 1));
    }
    editorRef.current?.focus();
  };

  const handleFindPrev = () => {
    editorRef.current?.findPrev();
    if (matchCount > 0) {
      setActiveIndex((prev) => (prev <= 1 ? matchCount : prev - 1));
    }
    editorRef.current?.focus();
  };

  if (!open) {
    return null;
  }

  const countLabel = keyword
    ? matchCount > 0
      ? `${activeIndex} / ${matchCount}`
      : '无结果'
    : '';

  return (
    <div className="knowledge-find-bar" role="search">
      <Input
        ref={inputRef as never}
        className="knowledge-find-input"
        size="small"
        allowClear
        placeholder="在当前文档内查找"
        value={keyword}
        onChange={(event) => setKeyword(event.target.value)}
        onPressEnter={(event) => {
          if (event.shiftKey) {
            handleFindPrev();
          } else {
            handleFindNext();
          }
        }}
        suffix={
          <Tooltip title="区分大小写">
            <button
              type="button"
              className={`knowledge-find-case-btn${caseSensitive ? ' is-active' : ''}`}
              onClick={() => setCaseSensitive((prev) => !prev)}
              aria-pressed={caseSensitive}
              aria-label="区分大小写"
            >
              Aa
            </button>
          </Tooltip>
        }
      />
      {countLabel && <span className="knowledge-find-count">{countLabel}</span>}
      <Tooltip title="上一个 (Shift+Enter)">
        <Button
          size="small"
          type="text"
          icon={<UpOutlined />}
          disabled={matchCount === 0}
          onClick={handleFindPrev}
          aria-label="上一个匹配"
        />
      </Tooltip>
      <Tooltip title="下一个 (Enter)">
        <Button
          size="small"
          type="text"
          icon={<DownOutlined />}
          disabled={matchCount === 0}
          onClick={handleFindNext}
          aria-label="下一个匹配"
        />
      </Tooltip>
      <Tooltip title="关闭 (Esc)">
        <Button
          size="small"
          type="text"
          icon={<CloseOutlined />}
          onClick={onClose}
          aria-label="关闭查找栏"
        />
      </Tooltip>
    </div>
  );
}
