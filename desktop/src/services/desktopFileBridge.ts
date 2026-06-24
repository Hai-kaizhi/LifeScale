import type { WriteDailyMarkdownFilePayload } from '../shared/types/dailyMarkdown';

interface WriteResult {
  success: boolean;
  message?: string;
}

export const MEMORY_VAULT_ROOT = '__memory_vault__';

function isTauriRuntime(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

export async function chooseMarkdownRootFolder(): Promise<string | null> {
  if (isTauriRuntime()) {
    const { open } = await import('@tauri-apps/plugin-dialog');
    const selected = await open({
      directory: true,
      multiple: false,
      title: '选择 Markdown 保存文件夹',
    });

    return typeof selected === 'string' ? selected : null;
  }

  const selected = window.prompt(
    '当前为浏览器预览模式，请输入一个模拟 Markdown 保存路径：',
    'E:\\LifeScaleMarkdown',
  );
  return selected?.trim() || null;
}

export async function ensureDefaultVaultRoot(): Promise<string> {
  if (!isTauriRuntime()) {
    return MEMORY_VAULT_ROOT;
  }

  const { invoke } = await import('@tauri-apps/api/core');
  return invoke<string>('ensure_default_vault_root');
}

export async function writeDailyMarkdownFile(
  payload: WriteDailyMarkdownFilePayload,
): Promise<WriteResult> {
  if (!isTauriRuntime()) {
    return {
      success: true,
      message: '浏览器预览模式：已模拟写入 Markdown 文件',
    };
  }

  try {
    const { invoke } = await import('@tauri-apps/api/core');
    await invoke('write_daily_markdown_file', {
      rootPath: payload.rootPath,
      relativePath: payload.relativePath,
      content: payload.content,
    });
    return { success: true };
  } catch (err) {
    return {
      success: false,
      message: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function writeMarkdownFile(
  payload: WriteDailyMarkdownFilePayload,
): Promise<WriteResult> {
  return writeDailyMarkdownFile(payload);
}
