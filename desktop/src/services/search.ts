import { getVaultEngineSingleton } from './vault';
import type { SearchResultItem, SearchResultKind } from '../shared/types/search';

/**
 * 本地全文搜索（开源本地版）。
 *
 * 扫描本地工作区所有 `.md` 文件，按关键词匹配标题与正文，返回最多 [limit] 条结果。
 * 私有版的 `/api/search` 全局索引（含任务/快速记录结构化检索）已移除；
 * 本地版在文件层面做大小写不敏感子串匹配，足以覆盖笔记/沉淀文档检索。
 */
export async function searchAll(
  keyword: string,
  pageNo = 1,
  pageSize = 50,
): Promise<{
  success: boolean;
  data: { list: SearchResultItem[]; total: number; keyword: string };
}> {
  const trimmed = keyword.trim();
  if (!trimmed) {
    return { success: true, data: { list: [], total: 0, keyword: '' } };
  }
  const engine = getVaultEngineSingleton();
  const needle = trimmed.toLowerCase();

  // engine 在未 init（无 vaultRoot）时 readLocalFile 返回空串，搜索自然为空。
  const { listVaultFiles } = await import('./vault/vaultFileBridge');
  const root = readVaultRootSafe();
  if (!root) {
    return { success: true, data: { list: [], total: 0, keyword: trimmed } };
  }

  const entries = await listVaultFiles(root);
  const results: SearchResultItem[] = [];
  for (const entry of entries) {
    let content: string;
    try {
      content = await engine.readLocalFile(entry.path);
    } catch {
      continue;
    }
    const title = entry.path.split('/').pop()?.replace(/\.md$/i, '') ?? entry.path;
    const titleHit = title.toLowerCase().includes(needle);
    const contentHit = content.toLowerCase().includes(needle);
    if (!titleHit && !contentHit) continue;

    const kind: SearchResultKind = titleHit ? 'document_title' : 'document_content';
    const snippet = buildSnippet(content, needle);
    results.push({
      id: entry.path,
      kind,
      title,
      snippet,
      location: entry.path,
      documentId: entry.path,
      updatedAt: new Date().toISOString(),
    });
    if (results.length >= pageSize * pageNo) break;
  }

  const start = (pageNo - 1) * pageSize;
  const page = results.slice(start, start + pageSize);
  return { success: true, data: { list: page, total: results.length, keyword: trimmed } };
}

const VAULT_ROOT_KEY = 'lifescale.vault.root';
function readVaultRootSafe(): string | null {
  try {
    return localStorage.getItem(VAULT_ROOT_KEY);
  } catch {
    return null;
  }
}

function buildSnippet(content: string, needle: string): string {
  const lower = content.toLowerCase();
  const idx = lower.indexOf(needle);
  if (idx < 0) return '';
  const start = Math.max(0, idx - 30);
  const end = Math.min(content.length, idx + needle.length + 50);
  const snippet = content.slice(start, end).replace(/\s+/g, ' ').trim();
  return (start > 0 ? '…' : '') + snippet + (end < content.length ? '…' : '');
}
