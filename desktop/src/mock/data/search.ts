import type { SearchListData, SearchResultItem } from '../../shared/types/search';
import { searchKnowledgeDocuments } from './knowledgeBase';

/**
 * 全局搜索 mock：跨知识库文档标题/内容命中。
 *
 * 历史还覆盖任务（schedule）与快速记录（quickNote），但这两类数据源已随 Model B 后端接口
 * 废弃删除——任务/快速记录改由本地 Daily Markdown 承载。搜索 mock 暂只保留文档命中，
 * 后续真实搜索将基于 vault Markdown 文件全文索引（P0 待办，见 docs/04 桌面端拆解）。
 */
export function searchAll(keyword: string, pageNo = 1, pageSize = 50): SearchListData {
  const trimmed = keyword.trim();
  const results: SearchResultItem[] = [];

  // 文档标题与内容命中。
  for (const hit of searchKnowledgeDocuments(trimmed)) {
    results.push({
      id: `doc-${hit.id}`,
      kind: hit.matchedField === 'title' ? 'document_title' : 'document_content',
      title: hit.title,
      snippet: hit.snippet,
      location: hit.location,
      documentId: hit.id,
      date: hit.date,
      updatedAt: hit.updatedAt,
    });
  }

  // 按更新时间倒序。
  results.sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));

  const start = (pageNo - 1) * pageSize;
  return {
    list: results.slice(start, start + pageSize),
    total: results.length,
    pageNo,
    pageSize,
    keyword: trimmed,
    status: results.length ? 'ok' : 'empty',
  };
}

