import { apiGet } from './client';
import { mockSearchAll } from '../mock/handlers/search';
import type { SearchListData } from '../shared/types/search';

export function searchAll(keyword: string, pageNo = 1, pageSize = 50) {
  const trimmed = keyword.trim();
  return apiGet<SearchListData>(
    `/search?keyword=${encodeURIComponent(trimmed)}&pageNo=${pageNo}&pageSize=${pageSize}`,
    () => mockSearchAll(trimmed, pageNo, pageSize),
  );
}
