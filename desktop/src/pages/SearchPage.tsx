import { Empty, Input, List, Skeleton, Tag, Typography, message } from 'antd';
import {
  FileTextOutlined,
  ProfileOutlined,
  SearchOutlined,
} from '@ant-design/icons';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { searchAll } from '../services/search';
import { ROUTES } from '../shared/constants';
import type { SearchResultItem, SearchResultKind } from '../shared/types/search';
import type { RequestStatus } from '../shared/types/api';
import './SearchPage.css';

const { Link: AntdLink } = Typography;

const KIND_LABEL: Record<SearchResultKind, string> = {
  document_title: '文档标题',
  document_content: '文档内容',
  task: '任务',
  note: '快速记录',
};

const KIND_COLOR: Record<SearchResultKind, string> = {
  document_title: 'blue',
  document_content: 'geekblue',
  task: 'gold',
  note: 'green',
};

function KindIcon({ kind }: { kind: SearchResultKind }) {
  if (kind === 'task' || kind === 'note') {
    return <ProfileOutlined />;
  }
  return <FileTextOutlined />;
}

export function SearchPage() {
  const navigate = useNavigate();
  const [keyword, setKeyword] = useState('');
  const [results, setResults] = useState<SearchResultItem[]>([]);
  const [total, setTotal] = useState(0);
  const [status, setStatus] = useState<RequestStatus>('idle');
  const [searched, setSearched] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const runSearch = useCallback(async (value: string) => {
    const trimmed = value.trim();
    if (!trimmed) {
      setResults([]);
      setTotal(0);
      setStatus('idle');
      setSearched(false);
      return;
    }
    setStatus('loading');
    try {
      const response = await searchAll(trimmed, 1, 50);
      if (!response.success) {
        setResults([]);
        setTotal(0);
        setStatus('error');
        message.warning('搜索失败，请重试');
        return;
      }
      setResults(response.data.list);
      setTotal(response.data.total);
      setStatus('success');
      setSearched(true);
    } catch {
      setResults([]);
      setTotal(0);
      setStatus('error');
      message.warning('搜索失败，请重试');
    }
  }, []);

  // 输入去抖动（300ms），避免每次按键都请求。
  useEffect(() => {
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    debounceRef.current = setTimeout(() => {
      void runSearch(keyword);
    }, 300);
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, [keyword, runSearch]);

  const handleOpenResult = (item: SearchResultItem) => {
    // 从搜索结果进入对应笔记或日期。文档结果跳转 Vault 笔记（搜索索引后续对齐 vault 文件）。
    if (item.documentId) {
      navigate(ROUTES.VAULT);
      return;
    }
    if (item.date) {
      navigate(`${ROUTES.TODAY}?date=${encodeURIComponent(item.date)}`);
    }
  };

  const hasQuery = Boolean(keyword.trim());
  const showEmpty = searched && status === 'success' && results.length === 0;

  const header = useMemo(
    () => (
      <header className="search-page-header">
        <h1>
          <SearchOutlined />
          搜索
        </h1>
        <p>查找文档标题与内容、任务和快速记录，点击结果可跳转到对应位置。</p>
      </header>
    ),
    [],
  );

  return (
    <div className="search-page">
      {header}

      <div className="search-page-box">
        <Input
          size="large"
          allowClear
          placeholder="输入关键词，搜索文档 / 任务 / 快速记录"
          prefix={<SearchOutlined />}
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
          onPressEnter={() => {
            if (debounceRef.current) {
              clearTimeout(debounceRef.current);
            }
            void runSearch(keyword);
          }}
        />
      </div>

      <section className="search-page-results">
        {status === 'loading' ? (
          <Skeleton active paragraph={{ rows: 5 }} />
        ) : showEmpty ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description={`没有找到与「${keyword.trim()}」相关的内容`}
            className="search-page-empty"
          />
        ) : results.length ? (
          <>
            <div className="search-page-summary">共找到 {total} 条结果</div>
            <List<SearchResultItem>
              itemLayout="vertical"
              dataSource={results}
              renderItem={(item) => (
                <List.Item key={item.id}>
                  <article className="search-result-item">
                    <div className="search-result-head">
                      <span className="search-result-icon">
                        <KindIcon kind={item.kind} />
                      </span>
                      <AntdLink
                        className="search-result-title"
                        onClick={() => handleOpenResult(item)}
                      >
                        {item.title}
                      </AntdLink>
                      <Tag color={KIND_COLOR[item.kind]}>{KIND_LABEL[item.kind]}</Tag>
                    </div>
                    <p className="search-result-snippet">{item.snippet}</p>
                    <div className="search-result-meta">
                      <span>{item.location}</span>
                    </div>
                  </article>
                </List.Item>
              )}
            />
          </>
        ) : (
          !hasQuery && (
            <Empty
              image={Empty.PRESENTED_IMAGE_SIMPLE}
              description="输入关键词，跨文档、任务和快速记录查找历史内容。"
              className="search-page-empty"
            />
          )
        )}
      </section>
    </div>
  );
}
