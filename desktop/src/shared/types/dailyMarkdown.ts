import type { ApiListData } from './api';

export type DailyMarkdownStatus =
  | 'ok'
  | 'empty'
  | 'missing_save_root'
  | 'readonly'
  | 'no_permission'
  | 'error';

export interface DailyMarkdownPermissions {
  canView: boolean;
  canEdit: boolean;
  canSave: boolean;
  canChooseFolder: boolean;
  canWriteToDisk: boolean;
  reason?: string;
}

export interface MarkdownSavedRecord {
  date: string;
  title: string;
  relativePath: string;
  absolutePath: string;
  savedAt: string;
}

export interface MarkdownSettings {
  saveRootPath: string;
  dailySubdirectory: string;
  dailyPathPattern: string;
  recentDocuments: MarkdownSavedRecord[];
  permissions: DailyMarkdownPermissions;
}

export interface DailyMarkdownDocument {
  date: string;
  title: string;
  fileName: string;
  relativePath: string;
  absolutePath: string;
  content: string;
  updatedAt: string;
  savedAt?: string;
  status: DailyMarkdownStatus;
  permissions: DailyMarkdownPermissions;
}

export interface UpdateMarkdownSettingsPayload {
  saveRootPath?: string;
  dailySubdirectory?: string;
}

export interface SaveDailyMarkdownPayload {
  date: string;
  content: string;
}

export interface WriteDailyMarkdownFilePayload {
  rootPath: string;
  relativePath: string;
  content: string;
}

export type DailyMarkdownListData =
  ApiListData<MarkdownSavedRecord, DailyMarkdownPermissions> & {
    status: DailyMarkdownStatus;
    permissions: DailyMarkdownPermissions;
  };
