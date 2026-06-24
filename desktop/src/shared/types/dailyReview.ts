import type { ApiListData } from './api';
import type { QuickNote } from './quickNote';
import type { Schedule } from './schedule';

export type DailyReviewStatus = 'not_started' | 'draft' | 'completed';

export type ReviewQuestionSchemeSource = 'official' | 'custom';

export type DailyReviewRequestStatus = 'ok' | 'empty' | 'readonly' | 'no_permission' | 'error';

export interface ReviewQuestion {
  id: string;
  title: string;
  placeholder: string;
  required: boolean;
  maxLength: number;
  sortOrder: number;
}

export interface ReviewQuestionScheme {
  id: string;
  name: string;
  source: ReviewQuestionSchemeSource;
  isDefault: boolean;
  questions: ReviewQuestion[];
}

export interface DailyReviewAnswer {
  questionId: string;
  content: string;
  updatedAt: string;
}

export interface DailyReview {
  id: string;
  date: string;
  schemeId: string;
  status: DailyReviewStatus;
  answers: DailyReviewAnswer[];
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

export interface DailyReviewSummary {
  taskTotal: number;
  completedCount: number;
  uncompletedCount: number;
  quickNoteCount: number;
  status: DailyReviewStatus;
}

export interface DailyReviewPermissions {
  canView: boolean;
  canSave: boolean;
  canEdit: boolean;
  canClear: boolean;
  canSelectScheme: boolean;
  reason?: string;
}

export interface DailyReviewMaterials {
  tasks: Schedule[];
  quickNotes: QuickNote[];
}

export interface DailyReviewDetailData {
  review: DailyReview;
  scheme: ReviewQuestionScheme;
  summary: DailyReviewSummary;
  materials: DailyReviewMaterials;
  status: DailyReviewRequestStatus;
  permissions: DailyReviewPermissions;
}

export interface ReviewQuestionSchemeListQuery {
  pageNo?: number;
  pageSize?: number;
}

export type ReviewQuestionSchemeListData =
  ApiListData<ReviewQuestionScheme, DailyReviewPermissions> & {
    status: DailyReviewRequestStatus;
    permissions: DailyReviewPermissions;
  };

export interface SaveDailyReviewAnswerPayload {
  questionId: string;
  content: string;
}

export interface SaveDailyReviewPayload {
  date: string;
  schemeId: string;
  answers: SaveDailyReviewAnswerPayload[];
}

export interface ReviewQuestionDraftPayload {
  id?: string;
  title: string;
  placeholder: string;
  required: boolean;
  maxLength?: number;
}

export interface CreateReviewQuestionSchemePayload {
  name: string;
  questions: ReviewQuestionDraftPayload[];
}

export interface UpdateReviewQuestionSchemePayload {
  id: string;
  name: string;
  questions: ReviewQuestionDraftPayload[];
}
