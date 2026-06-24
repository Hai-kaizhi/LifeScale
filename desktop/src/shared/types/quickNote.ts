import type { ApiListData } from './api';

export type QuickNoteStatus = 'active' | 'deleted';

// TODO: Align source device enum with backend once multi-device sync contracts are defined.
export type QuickNoteSourceDevice = 'desktop';

export type QuickNoteListStatus = 'ok' | 'empty' | 'readonly' | 'error';

export interface QuickNote {
  id: string;
  date: string;
  content: string;
  sourceDevice: QuickNoteSourceDevice;
  status: QuickNoteStatus;
  createdAt: string;
  updatedAt: string;
}

export interface QuickNotePermissions {
  canView: boolean;
  canCreate: boolean;
  canUpdate: boolean;
  canDelete: boolean;
  reason?: string;
}

export interface QuickNoteListQuery {
  date: string;
  pageNo?: number;
  pageSize?: number;
  status?: QuickNoteStatus;
}

export interface CreateQuickNotePayload {
  content: string;
  date?: string;
}

export interface UpdateQuickNotePayload {
  id: string;
  content: string;
}

export type QuickNoteListData = ApiListData<QuickNote, QuickNotePermissions> & {
  status: QuickNoteListStatus;
  permissions: QuickNotePermissions;
};
