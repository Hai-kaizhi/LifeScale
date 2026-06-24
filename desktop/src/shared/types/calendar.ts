import type { Schedule } from './schedule';

export type CalendarMarkerType = 'schedule' | 'review';

export interface CalendarMarker {
  date: string;
  type: CalendarMarkerType;
  color: string;
  count?: number;
}

export interface CalendarDayMarker {
  type: CalendarMarkerType;
  count: number;
  color: string;
}

export interface CalendarDay {
  date: string;
  schedules: Schedule[];
  markers: CalendarDayMarker[];
}

export interface CalendarMonth {
  month: string;
  days: CalendarDay[];
}
