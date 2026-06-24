import type { ApiResponse } from '../../shared/types/api';
import type { SearchListData } from '../../shared/types/search';
import { searchAll } from '../data/search';

export function mockSearchAll(keyword: string, pageNo = 1, pageSize = 50): ApiResponse<SearchListData> {
  const data = searchAll(keyword, pageNo, pageSize);
  return {
    code: 200,
    success: true,
    message: data.status === 'empty' ? '没有匹配的结果' : 'ok',
    data,
    status: data.status,
  };
}
