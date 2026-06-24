import { apiPut } from './client';
import { mockUpdateMarkdownSettings } from '../mock/handlers/dailyMarkdown';
import type {
  MarkdownSettings,
  UpdateMarkdownSettingsPayload,
} from '../shared/types/dailyMarkdown';

/**
 * Markdown 设置相关服务。
 *
 * 本地优先架构下，Markdown 设置（dailySubdirectory）以 localStorage 为事实来源
 *（见 hooks/useMarkdownSettings）。本服务仅保留 `updateMarkdownSettings`，用于登录态 best-effort
 * 镜像到云端（失败静默忽略，不影响本地功能）。
 *
 * 历史 generate/source/list/disk 写入等函数已随 Model B 后端接口废弃删除——
 * Daily 文档正文改由本地 vault Markdown 文件承载（services/vault/*）。
 */
export function updateMarkdownSettings(payload: UpdateMarkdownSettingsPayload) {
  return apiPut<MarkdownSettings>(
    '/markdown/settings',
    payload,
    () => mockUpdateMarkdownSettings(payload),
  );
}
