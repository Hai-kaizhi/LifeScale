import type { ApiListData } from './api';

/** 全局搜索的内容类型：与 PRD 13.10 搜索范围对齐。 */
export type SearchResultKind = 'document_title' | 'document_content' | 'task' | 'note';

export interface SearchResultItem {
  id: string;
  kind: SearchResultKind;
  title: string;
  /** 命中内容的片段预览，便于用户判断是否为目标内容。 */
  snippet: string;
  /** 所属位置：文档路径或日期。 */
  location: string;
  /** 用于结果跳转：文档 ID 或日期。 */
  documentId?: string;
  date?: string;
  updatedAt: string;
}

export interface SearchAllQuery {
  keyword: string;
  pageNo?: number;
  pageSize?: number;
}

export type SearchListData = ApiListData<SearchResultItem> & {
  keyword: string;
};

export type SearchListStatus = 'ok' | 'empty' | 'error';
