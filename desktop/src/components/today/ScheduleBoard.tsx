import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { Button, Dropdown, Tooltip } from 'antd';
import {
  CalendarOutlined,
  CheckOutlined,
  ClockCircleOutlined,
  DeleteOutlined,
  EditOutlined,
  LoadingOutlined,
  PlusOutlined,
  StarFilled,
  StarOutlined,
  SwapOutlined,
} from '@ant-design/icons';
import type { Schedule } from '../../shared/types/schedule';
import type { SchedulePeriod } from '../../shared/types/schedulePeriod';
import type { ScheduleType } from '../../shared/types/schedule';
import { MAX_FOCUS_PER_DAY } from '../../shared/types/schedule';
import { TodoListPanel } from './TodoListPanel';

interface ScheduleBoardProps {
  schedules: Schedule[];
  periods: SchedulePeriod[];
  title?: string;
  addButtonText?: string;
  focusEmptyText?: string;
  readonly?: boolean;
  readonlyReason?: string;
  showTodoPanel?: boolean;
  loading?: boolean;
  onOpenCreate: () => void;
  onToggleSchedule?: (schedule: Schedule) => void;
  onDeleteSchedule?: (schedule: Schedule) => void;
  /** 打开编辑弹窗 */
  onEditSchedule?: (schedule: Schedule) => void;
  /** 转换日程类型：task ↔ note */
  onConvertSchedule?: (schedule: Schedule, type: ScheduleType) => void;
  /** 标记/取消今日重点 */
  onToggleFocus?: (schedule: Schedule) => void;
  /** 今日清单拖拽排序后回调 */
  onReorder?: (schedules: Schedule[]) => void;
}

interface PeriodLayout {
  period: SchedulePeriod;
  topPx: number;
  heightPx: number;
  pxPerMinute: number;
}

interface HourTick {
  hour: number;
  top: number;
  label: string;
}

const BASE_HOUR_PX = 22;
// 空时段参与整体缩放，但最终高度会保留时段名称与时间可读所需的下限。
const BASE_EMPTY_PERIOD_PX = 40;
const BASE_MIN_PERIOD_PX = 52;
const PERIOD_LABEL_MIN_PX = 56;
// 相邻卡片之间的视觉间距：仅在渲染层减去，不改变时间→像素的精确映射
const CARD_GAP_PX = 4;
// 卡片最小高度：与刻度密度解耦，刻度变密时卡片仍保持可读高度
const CARD_MIN_HEIGHT_PX = 44;
// 同一时段并排卡片（左右）之间的水平间距，仅在 count >= 2 时生效
const CARD_HGAP_PX = 6;
// 缩放上下限，避免极端尺寸下卡片不可读或过大
const MIN_SCALE = 0.4;
const MAX_SCALE = 1.6;
// 时间轴左侧区域需同时容纳时段标签与小时刻度，钳制区间保证名称不被挤压。
const TIMELINE_LABEL_RATIO = 0.2;
const TIMELINE_LABEL_MIN = 136;
const TIMELINE_LABEL_MAX = 196;

function toMinutes(time: string): number {
  if (time === '24:00') return 24 * 60;
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

function sortSchedules(schedules: Schedule[]): Schedule[] {
  return [...schedules].sort((a, b) => {
    const startDiff = toMinutes(a.startTime) - toMinutes(b.startTime);
    if (startDiff !== 0) return startDiff;
    const endDiff = toMinutes(a.endTime) - toMinutes(b.endTime);
    if (endDiff !== 0) return endDiff;
    return (a.createdAt ?? '').localeCompare(b.createdAt ?? '');
  });
}

function belongsToPeriod(schedule: Schedule, period: SchedulePeriod): boolean {
  const startMinute = toMinutes(schedule.startTime);
  return startMinute >= period.startMinute && startMinute < period.endMinute;
}

function getPeriodHeight(
  period: SchedulePeriod,
  hasSchedules: boolean,
  scale: number,
): number {
  if (!hasSchedules) {
    return Math.max(PERIOD_LABEL_MIN_PX, BASE_EMPTY_PERIOD_PX * scale);
  }

  const proportional = ((period.endMinute - period.startMinute) / 60) * BASE_HOUR_PX * scale;
  return Math.max(PERIOD_LABEL_MIN_PX, BASE_MIN_PERIOD_PX * scale, proportional);
}

function buildPeriodLayouts(
  periods: SchedulePeriod[],
  schedules: Schedule[],
  scale: number,
): PeriodLayout[] {
  const sortedPeriods = [...periods].sort((a, b) => a.sortOrder - b.sortOrder);
  let cursor = 0;
  return sortedPeriods.map((period) => {
    const has = schedules.some((schedule) => belongsToPeriod(schedule, period));
    const heightPx = getPeriodHeight(period, has, scale);
    const layout: PeriodLayout = {
      period,
      topPx: cursor,
      heightPx,
      pxPerMinute: heightPx / (period.endMinute - period.startMinute),
    };
    cursor += heightPx;
    return layout;
  });
}

function findPeriodAtMinute(minute: number, layouts: PeriodLayout[]): PeriodLayout | null {
  if (minute < 0) minute = 0;
  if (minute >= 24 * 60) minute = 24 * 60 - 1;
  return (
    layouts.find(
      (layout) => minute >= layout.period.startMinute && minute < layout.period.endMinute,
    ) ?? null
  );
}

interface CardLayout {
  top: number;
  height: number;
}

function getCardLayout(schedule: Schedule, layouts: PeriodLayout[]): CardLayout | null {
  const startMin = toMinutes(schedule.startTime);
  const endMin = toMinutes(schedule.endTime);

  const startLayout = findPeriodAtMinute(startMin, layouts);
  // 结束时间正好是 24:00 时回退到末段
  const endLayout =
    findPeriodAtMinute(endMin - 1, layouts) ??
    layouts.find((layout) => layout.period.endMinute === endMin) ??
    startLayout;
  if (!startLayout || !endLayout) return null;

  const top =
    startLayout.topPx +
    (startMin - startLayout.period.startMinute) * startLayout.pxPerMinute;
  const bottom =
    endLayout.topPx +
    (endMin - endLayout.period.startMinute) * endLayout.pxPerMinute;
  const naturalHeight = bottom - top;
  // 最小高度用与刻度密度解耦的固定值，刻度变密时卡片仍保持可读
  const minHeight = CARD_MIN_HEIGHT_PX;
  const height = Math.max(naturalHeight, minHeight);

  return { top, height };
}

function groupOverlapping(schedules: Schedule[]): Schedule[][] {
  const sorted = sortSchedules(schedules);
  const groups: Schedule[][] = [];
  let current: Schedule[] = [];
  let groupEnd = -1;

  for (const schedule of sorted) {
    const start = toMinutes(schedule.startTime);
    const end = toMinutes(schedule.endTime);
    if (current.length === 0 || start >= groupEnd) {
      if (current.length > 0) groups.push(current);
      current = [schedule];
      groupEnd = end;
    } else {
      current.push(schedule);
      groupEnd = Math.max(groupEnd, end);
    }
  }
  if (current.length > 0) groups.push(current);
  return groups;
}

/**
 * 24h 制时间标签：去掉前导零，如 0 → '0:00'，9 → '9:00'，15 → '15:00'。
 */
function formatHourLabel(hour: number): string {
  return `${hour}:00`;
}

function buildHourTicks(periodLayouts: PeriodLayout[]): HourTick[] {
  const ticks: HourTick[] = [];
  const seen = new Set<number>();

  for (const layout of periodLayouts) {
    const { period, topPx, pxPerMinute } = layout;
    const startHour = Math.ceil(period.startMinute / 60);
    const endHour = period.endMinute / 60;

    // 只生成大刻度（每 3 小时：0/3/6/9/12/15/18/21），刻度左侧带时间标签
    for (let hour = startHour; hour <= endHour; hour++) {
      if (hour % 3 !== 0) continue;
      if (seen.has(hour)) continue;

      seen.add(hour);
      const minute = hour * 60;
      const top = topPx + (minute - period.startMinute) * pxPerMinute;
      ticks.push({ hour, top, label: formatHourLabel(hour) });
    }
  }
  return ticks;
}

export function ScheduleBoard({
  schedules,
  periods,
  title = '今日日程',
  addButtonText = '新建日程',
  focusEmptyText = `右键日程可设为今日重点（最多 ${MAX_FOCUS_PER_DAY} 个）`,
  readonly = false,
  readonlyReason,
  showTodoPanel = true,
  loading = false,
  onOpenCreate,
  onToggleSchedule,
  onDeleteSchedule,
  onEditSchedule,
  onConvertSchedule,
  onToggleFocus,
  onReorder,
}: ScheduleBoardProps) {
  const visualRef = useRef<HTMLDivElement | null>(null);
  const [containerHeight, setContainerHeight] = useState(0);
  const [containerWidth, setContainerWidth] = useState(0);

  // 监听 visual 容器尺寸变化：高度用于纵向缩放，宽度用于横向标签列自适应
  useEffect(() => {
    const el = visualRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerHeight(entry.contentRect.height);
        setContainerWidth(entry.contentRect.width);
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // 先按 scale=1 计算 base 总高度，再反算 scale
  const baseLayouts = useMemo(
    () => buildPeriodLayouts(periods, schedules, 1),
    [periods, schedules],
  );
  const baseTotalHeight = baseLayouts.length
    ? baseLayouts[baseLayouts.length - 1].topPx + baseLayouts[baseLayouts.length - 1].heightPx
    : 0;

  const scale = useMemo(() => {
    if (containerHeight <= 0 || baseTotalHeight <= 0) return 1;
    const raw = containerHeight / baseTotalHeight;
    return Math.min(MAX_SCALE, Math.max(MIN_SCALE, raw));
  }, [containerHeight, baseTotalHeight]);

  // 时段标签列宽度 = 面板宽度 × 比例，并钳制在可读区间；为 0 时不注入，回退到 CSS 默认值
  const timelineLabelWidth = useMemo(() => {
    if (containerWidth <= 0) return 0;
    return Math.min(
      TIMELINE_LABEL_MAX,
      Math.max(TIMELINE_LABEL_MIN, Math.round(containerWidth * TIMELINE_LABEL_RATIO)),
    );
  }, [containerWidth]);

  const periodLayouts = useMemo(
    () => buildPeriodLayouts(periods, schedules, scale),
    [periods, schedules, scale],
  );
  const overlapGroups = useMemo(() => groupOverlapping(schedules), [schedules]);
  const hourTicks = useMemo(() => buildHourTicks(periodLayouts), [periodLayouts]);

  const totalHeight = useMemo(() => {
    if (!periodLayouts.length) return 0;
    const last = periodLayouts[periodLayouts.length - 1];
    let bottom = last.topPx + last.heightPx;
    for (const group of overlapGroups) {
      for (const schedule of group) {
        const layout = getCardLayout(schedule, periodLayouts);
        if (layout) {
          bottom = Math.max(bottom, layout.top + layout.height);
        }
      }
    }
    return bottom;
  }, [periodLayouts, overlapGroups]);

  return (
    <section
      className={`schedule-board-card${loading ? ' is-loading' : ''}${readonly ? ' is-readonly' : ''}${!showTodoPanel ? ' is-timeline-only' : ''}`}
      aria-label="今日时间轴与日程安排"
      aria-busy={loading}
    >
      <header className="schedule-board-topbar">
        <div className="schedule-board-topbar-title">
          <CalendarOutlined />
          <span>{title}</span>
        </div>
        <Button
          type="primary"
          className="schedule-heading-add"
          icon={<PlusOutlined />}
          disabled={readonly}
          onClick={onOpenCreate}
        >
          {addButtonText}
        </Button>
      </header>

      {/* 今日重点条：展示当天被标记为重点的日程 */}
      <FocusBar schedules={schedules} emptyText={focusEmptyText} />

      {readonly && readonlyReason && (
        <div className="schedule-board-readonly" role="note">
          {readonlyReason}
        </div>
      )}

      <div className="schedule-board-grid">
        <div className="schedule-timeline-panel">
          <div className="schedule-panel-heading">
            <div className="schedule-heading-title">
              <ClockCircleOutlined />
              <span>时间轴</span>
            </div>
          </div>

          <div
            className="schedule-timeline-visual"
            ref={visualRef}
            style={
              timelineLabelWidth
                ? ({ '--timeline-label-w': `${timelineLabelWidth}px` } as CSSProperties)
                : undefined
            }
          >
        <div
          className="schedule-timeline-track"
          style={{ height: totalHeight }}
        >
          {periodLayouts.map(({ period, topPx, heightPx }) => (
            <div
              key={period.id}
              className={`schedule-period-label schedule-period-${period.code}`}
              style={{ top: topPx, height: heightPx }}
            >
              <div className="schedule-period-label-card">
                <span className="schedule-period-name">{period.name}</span>
                <span className="schedule-period-time">{period.startTime}-{period.endTime}</span>
              </div>
            </div>
          ))}

          {periodLayouts.slice(0, -1).map(({ period, topPx, heightPx }) => (
            <div
              key={`divider-${period.id}`}
              className="schedule-period-divider"
              style={{ top: topPx + heightPx }}
            />
          ))}

          {hourTicks.map((tick) => (
            <div
              key={`tick-${tick.hour}`}
              className="schedule-tick-row"
              style={{ top: tick.top }}
              aria-hidden="true"
            >
              <span className="schedule-tick-label">{tick.label}</span>
              <div className="schedule-tick is-major" />
            </div>
          ))}

          <div className="schedule-cards-layer">
            {overlapGroups.flatMap((group) =>
              group.map((schedule, index) => {
                const layout = getCardLayout(schedule, periodLayouts);
                if (!layout) return null;
                // 记录类型仅作备忘，不参与完成状态
                const isNote = schedule.type === 'note';
                // 多张并排卡片时，各自留出左右水平间距；单卡保持占满整行
                const count = group.length;
                const hasHGutter = count >= 2;
                const colW = `${100 / count}%`;
                const cardStyle = {
                  top: layout.top,
                  height: Math.max(layout.height - CARD_GAP_PX, 0),
                  left: `calc(${(index * 100) / count}%${hasHGutter ? ` + ${CARD_HGAP_PX}px` : ''})`,
                  width: hasHGutter ? `calc(${colW} - ${CARD_HGAP_PX * 2}px)` : colW,
                  '--schedule-color': schedule.categoryColor,
                } as CSSProperties;

                // 右键菜单：记录类型不显示「标记为已完成」
                const menuItems = [];
                if (!readonly && !isNote) {
                  menuItems.push({
                    key: 'toggle',
                    label: schedule.completed ? '标记为未完成' : '标记为已完成',
                    icon: <CheckOutlined />,
                    onClick: () => onToggleSchedule?.(schedule),
                  });
                  menuItems.push({ type: 'divider' as const });
                }
                if (!readonly) {
                  menuItems.push({
                    key: 'convert',
                    label: isNote ? '转为任务' : '转为记录',
                    icon: <SwapOutlined />,
                    onClick: () => onConvertSchedule?.(schedule, isNote ? 'task' : 'note'),
                  });
                }
                // 标记/取消今日重点
                if (!readonly && !isNote) {
                  menuItems.push({
                  key: 'focus',
                  label: schedule.focus ? '取消今日重点' : '设为今日重点',
                  icon: schedule.focus ? <StarFilled style={{ color: '#ef4444' }} /> : <StarOutlined />,
                  onClick: () => onToggleFocus?.(schedule),
                  });
                }
                if (!readonly) {
                  menuItems.push({ type: 'divider' as const });
                  menuItems.push({
                    key: 'edit',
                    label: '编辑',
                    icon: <EditOutlined />,
                    onClick: () => onEditSchedule?.(schedule),
                  });
                  menuItems.push({
                    key: 'delete',
                    label: '删除',
                    icon: <DeleteOutlined />,
                    danger: true,
                    onClick: () => onDeleteSchedule?.(schedule),
                  });
                }

                const card = (
                  <Tooltip
                    title={
                      readonly
                        ? `${schedule.title}（${schedule.startTime}-${schedule.endTime}）`
                        : `${schedule.title}（${schedule.startTime}-${schedule.endTime}）· 双击编辑`
                    }
                    placement="right"
                  >
                    <article
                      className={`schedule-card${
                        schedule.completed && !isNote ? ' is-completed' : ''
                      }${isNote ? ' is-note' : ''}${schedule.focus ? ' is-focus' : ''}`}
                      style={cardStyle}
                      onDoubleClick={() => {
                        if (!readonly) {
                          onEditSchedule?.(schedule);
                        }
                      }}
                    >
                      {schedule.focus && (
                        <StarFilled className="schedule-card-focus-badge" style={{ color: '#ef4444' }} />
                      )}
                      <strong className="schedule-card-title">{schedule.title}</strong>
                      <span className="schedule-card-time">
                        {schedule.startTime}-{schedule.endTime}
                      </span>
                    </article>
                  </Tooltip>
                );

                return readonly ? (
                  <div key={schedule.id}>{card}</div>
                ) : (
                  <Dropdown
                    key={schedule.id}
                    trigger={['contextMenu']}
                    menu={{ items: menuItems }}
                  >
                    {card}
                  </Dropdown>
                );
              }),
            )}
          </div>
        </div>
        </div>
        </div>

        {showTodoPanel && (
          <TodoListPanel
            schedules={schedules}
            onToggle={onToggleSchedule ?? (() => undefined)}
            onDelete={onDeleteSchedule ?? (() => undefined)}
            onOpenCreate={onOpenCreate}
            onEdit={onEditSchedule}
            onConvert={onConvertSchedule}
            onToggleFocus={onToggleFocus}
            onReorder={onReorder}
          />
        )}
      </div>

      {loading && (
        <div className="schedule-board-loading" role="status">
          <LoadingOutlined />
          <span>正在切换日期...</span>
        </div>
      )}
    </section>
  );
}

/**
 * 今日重点条：横向展示当天被标记为重点的日程。
 * 空时显示弱提示，引导用户右键日程设为重点。
 */
function FocusBar({ schedules, emptyText }: { schedules: Schedule[]; emptyText: string }) {
  const focusSchedules = schedules.filter((s) => s.focus);
  if (focusSchedules.length === 0) {
    return (
      <div className="schedule-focus-bar is-empty">
        <StarOutlined className="schedule-focus-empty-icon" />
        <span className="schedule-focus-empty-text">{emptyText}</span>
      </div>
    );
  }
  return (
    <div className="schedule-focus-bar" role="region" aria-label="今日重点">
      <StarFilled className="schedule-focus-bar-icon" />
      <div className="schedule-focus-chips">
        {focusSchedules.map((s) => (
          <span key={s.id} className="schedule-focus-chip">
            <strong className="schedule-focus-chip-title">{s.title}</strong>
            <span className="schedule-focus-chip-time">{s.startTime}-{s.endTime}</span>
          </span>
        ))}
      </div>
    </div>
  );
}
