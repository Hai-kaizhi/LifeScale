import dayjs from 'dayjs';
import type { CalendarDay, CalendarDayMarker, CalendarMonth } from '../../shared/types/calendar';
import { parseDailyDoc } from './dailyDoc';

const MARKER_COLORS = { schedule: '#22c55e', review: '#7c3aed' } as const;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function buildMarkers(scheduleCount: number, reviewHasContent: boolean): CalendarDayMarker[] {
  const markers: CalendarDayMarker[] = [];
  if (scheduleCount > 0) {
    markers.push({ type: 'schedule', count: scheduleCount, color: MARKER_COLORS.schedule });
  }
  if (reviewHasContent) {
    markers.push({ type: 'review', count: 1, color: MARKER_COLORS.review });
  }
  return markers;
}

export interface DeriveCalendarMonthDeps {
  dailySubdir: string;
  listFiles: () => Promise<readonly { path: string }[]>;
  readFile: (vaultPath: string) => Promise<string>;
}

/**
 * 扫描本地 `<subdir>/<YYYY-MM-DD>.md` 派生月历标记（本地优先，替代 REST getCalendarMonth）：
 * - 有日程（schedules.length>0）→ schedule 标记（count=日程数）。
 * - 复盘有非空内容 → review 标记。
 * 输出全月天数（无文件的日期 markers 为空），形状对齐 CalendarMonth，MiniCalendar 无需改。
 */
export async function deriveCalendarMonth(
  month: string,
  deps: DeriveCalendarMonthDeps,
): Promise<CalendarMonth> {
  const monthStart = dayjs(`${month}-01`);
  const daysInMonth = monthStart.daysInMonth();
  const subdirPrefix = `${deps.dailySubdir}/`;
  const monthPrefix = `${month}-`;

  const all = await deps.listFiles();
  const markersByDate = new Map<string, CalendarDayMarker[]>();

  for (const entry of all) {
    if (!entry.path.startsWith(subdirPrefix)) continue;
    const base = entry.path.slice(subdirPrefix.length);
    const date = base.endsWith('.md') ? base.slice(0, -3) : base;
    if (!DATE_RE.test(date) || !date.startsWith(monthPrefix)) continue;

    const raw = await deps.readFile(entry.path);
    const { model } = parseDailyDoc(raw, { date });
    const scheduleCount = model.schedules.length;
    const reviewHasContent = model.review.some((r) => r.content.trim());
    markersByDate.set(date, buildMarkers(scheduleCount, reviewHasContent));
  }

  const days: CalendarDay[] = Array.from({ length: daysInMonth }, (_, index) => {
    const date = monthStart.date(index + 1).format('YYYY-MM-DD');
    return { date, schedules: [], markers: markersByDate.get(date) ?? [] };
  });

  return { month, days };
}

// ============================ settled 驱动月历（docs/09 P3）============================

export interface DeriveSettlementMonthDeps {
  /** 取当月有沉淀记录的日期集合（调 ls_list_settled_dates_in_month）。 */
  listSettledDates: (yearMonth: string) => Promise<string[]>;
}

const SETTLEMENT_MARKER: CalendarDayMarker = { type: 'review', count: 1, color: MARKER_COLORS.review };

/**
 * 按 ls_daily_settlement 记录派生月历标记（docs/09 §8 settled 驱动，替代扫 .md）。
 * 有沉淀记录的日期 → review 标记；其余空。最符合「沉淀分层」语义且性能好（单查 SQL）。
 */
export async function deriveCalendarMonthFromSettlements(
  month: string,
  deps: DeriveSettlementMonthDeps,
): Promise<CalendarMonth> {
  const monthStart = dayjs(`${month}-01`);
  const daysInMonth = monthStart.daysInMonth();
  const settled = new Set(await deps.listSettledDates(month));

  const days: CalendarDay[] = Array.from({ length: daysInMonth }, (_, index) => {
    const date = monthStart.date(index + 1).format('YYYY-MM-DD');
    return { date, schedules: [], markers: settled.has(date) ? [SETTLEMENT_MARKER] : [] };
  });

  return { month, days };
}
