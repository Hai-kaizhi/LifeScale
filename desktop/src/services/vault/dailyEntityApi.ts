import { apiGet, apiPut } from '../client';
import type { ApiResponse } from '../../shared/types/api';
import type {
  DailyEntityChangesData,
  DailyEntityPushPayload,
  DailyEntitySyncResult,
} from '../../shared/types/dailyEntitySync';

/**
 * Daily 实体同步 API client（docs/09 §9.3）。
 *
 * 仅登录态+联网时由同步引擎调用（runtimeMode 短路、apiGet/apiPut 内部已处理 local 态）。
 * 非 Tauri/无后端的浏览器 dev 走 mock 兜底（返回空变更，不阻塞同步流程）。
 */

/** 推送当天未沉淀实体（LWW）。 */
export function pushDailyEntities(payload: DailyEntityPushPayload): Promise<ApiResponse<DailyEntitySyncResult>> {
  return apiPut<DailyEntitySyncResult>('/vault/daily-entities', payload, () => ({
    code: 0,
    success: true,
    message: 'mock',
    data: { pushed: 0, skipped: 0 },
  }));
}

/** 增量变更（按 updated_at 游标，含墓碑）。 */
export function getDailyEntityChanges(since?: string, limit?: number): Promise<ApiResponse<DailyEntityChangesData>> {
  const search = new URLSearchParams();
  if (since) search.set('since', since);
  if (limit) search.set('limit', String(limit));
  const q = search.toString();
  return apiGet<DailyEntityChangesData>(`/vault/daily-entities/changes${q ? `?${q}` : ''}`, () => ({
    code: 0,
    success: true,
    message: 'mock',
    data: {
      schedules: [],
      quickNotes: [],
      reviewAnswers: [],
      dailyFocuses: [],
      nextCursor: new Date().toISOString(),
      hasMore: false,
    },
  }));
}
