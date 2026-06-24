import type { ApiListData } from './api';
import type { DailyMarkdownDocument, DailyMarkdownStatus } from './dailyMarkdown';
import type {
  DailyReview,
  DailyReviewPermissions,
  DailyReviewStatus,
  ReviewQuestionScheme,
} from './dailyReview';
import type { QuickNote } from './quickNote';
import type { Schedule } from './schedule';

export type CalendarReviewViewMode = 'day' | 'week' | 'month';

export type CalendarDateMarkerType =
  | 'schedule'
  | 'quick_note'
  | 'review_completed'
  | 'review_pending'
  | 'empty';

export type CalendarReviewStatus = 'ok' | 'empty' | 'readonly' | 'no_permission' | 'error';

export interface CalendarDateMarker {
  type: CalendarDateMarkerType;
  label: string;
  color: string;
  count?: number;
}

export interface CalendarReviewPermissions {
  canView: boolean;
  canBackfillQuickNote: boolean;
  canEditReview: boolean;
  canViewMarkdown: boolean;
  canEditMarkdown: boolean;
  reason?: string;
}

export interface CalendarSchedulePreview {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
  category: string;
}

export interface CalendarQuickNotePreview {
  id: string;
  time: string;
  content: string;
}

export interface CalendarDayOverview {
  date: string;
  weekday: string;
  lunarLabel?: string;
  markers: CalendarDateMarker[];
  scheduleCount: number;
  quickNoteCount: number;
  schedulePreview: CalendarSchedulePreview[];
  quickNotePreview: CalendarQuickNotePreview[];
  reviewStatus: DailyReviewStatus;
  markdownStatus: DailyMarkdownStatus;
  status: CalendarReviewStatus;
  permissions: CalendarReviewPermissions;
}

export interface CalendarReviewSummary {
  review: DailyReview;
  scheme: ReviewQuestionScheme;
  permissions: DailyReviewPermissions;
}

export interface CalendarDayDetail {
  overview: CalendarDayOverview;
  schedules: Schedule[];
  quickNotes: QuickNote[];
  review: CalendarReviewSummary;
  markdown: DailyMarkdownDocument;
  permissions: CalendarReviewPermissions;
  status: CalendarReviewStatus;
}

export type CalendarWeekOverview = ApiListData<CalendarDayOverview, CalendarReviewPermissions> & {
  startDate: string;
  endDate: string;
  status: CalendarReviewStatus;
  permissions: CalendarReviewPermissions;
};

export type CalendarMonthOverview = ApiListData<CalendarDayOverview, CalendarReviewPermissions> & {
  month: string;
  status: CalendarReviewStatus;
  permissions: CalendarReviewPermissions;
};
