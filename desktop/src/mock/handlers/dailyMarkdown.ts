import type { ApiResponse } from '../../shared/types/api';
import type {
  MarkdownSettings,
  UpdateMarkdownSettingsPayload,
} from '../../shared/types/dailyMarkdown';
import * as data from '../data/dailyMarkdown';

/**
 * Markdown 设置 mock。
 *
 * 仅保留 `mockUpdateMarkdownSettings`（配合 services/dailyMarkdown.ts 的唯一函数）。
 * 历史 generate/source/list/saved 等 mock 随 Model B 后端接口废弃删除。
 */
export function mockUpdateMarkdownSettings(
  payload: UpdateMarkdownSettingsPayload,
): ApiResponse<MarkdownSettings> {
  const settings = data.updateMarkdownSettings(payload);
  return {
    code: 200,
    success: true,
    message: settings.saveRootPath ? 'Markdown 保存位置已更新' : '已清空 Markdown 保存位置',
    data: settings,
    status: settings.saveRootPath ? 'ok' : 'missing_save_root',
    permissions: settings.permissions,
  };
}
