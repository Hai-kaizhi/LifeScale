import { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, message, notification } from 'antd';
import dayjs from 'dayjs';
import { useCurrentDate } from '../../contexts/CurrentDateContext';
import { GreetingSection } from './GreetingSection';
import { ScheduleBoard } from './ScheduleBoard';
import { QuickNotes } from './QuickNotes';
import { MiniCalendar } from './MiniCalendar';
import { ScheduleFormModal } from './ScheduleFormModal';
import { LoadingSpinner } from '../common/LoadingSpinner';
import { useDailyDoc } from '../../hooks/vault/useDailyDoc';
import { useLocalCalendarMonth } from '../../hooks/vault/useLocalCalendarMonth';
import type { Schedule, ScheduleType } from '../../shared/types/schedule';
import { MAX_FOCUS_PER_DAY } from '../../shared/types/schedule';
import {
  DEFAULT_SCHEDULE_PERIODS,
  type SchedulePeriod,
} from '../../shared/types/schedulePeriod';
import { formatDisplayDate, getWeekday } from '../../shared/utils/date';

function getMonthKey(date: string): string {
  return dayjs(date).format('YYYY-MM');
}

function toMinutes(time: string): number {
  if (time === '24:00') return 24 * 60;
  const [hour, minute] = time.split(':').map(Number);
  return hour * 60 + minute;
}

/** 时间线展示排序：按开始时间、再结束时间、再 createdAt。 */
function sortSchedules(schedules: Schedule[]): Schedule[] {
  return [...schedules].sort((a, b) => {
    const startDiff = toMinutes(a.startTime) - toMinutes(b.startTime);
    if (startDiff !== 0) return startDiff;
    const endDiff = toMinutes(a.endTime) - toMinutes(b.endTime);
    if (endDiff !== 0) return endDiff;
    return (a.createdAt ?? '').localeCompare(b.createdAt ?? '');
  });
}

export function TodayPage() {
  const { currentDate, setCurrentDate } = useCurrentDate();
  // 当日日程来自本地 Daily Doc（本地优先）
  const { model, loading: docLoading, setSchedules: setDocSchedules } = useDailyDoc(currentDate);
  // 迷你月历标记：扫描本地 Daily/*.md 派生（本地优先）
  const { monthData: currentMonthData, loading: calendarLoading } = useLocalCalendarMonth(
    getMonthKey(currentDate),
  );

  const [schedulePeriods] = useState<SchedulePeriod[]>(
    DEFAULT_SCHEDULE_PERIODS,
  );
  const [initialLoading, setInitialLoading] = useState(true);
  const [scheduleModalOpen, setScheduleModalOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Schedule | null>(null);

  // 当日日程：从本地模型派生（时间线排序）
  const schedules = useMemo(() => sortSchedules(model?.schedules ?? []), [model]);

  useEffect(() => {
    if (model) setInitialLoading(false);
  }, [model]);

  // ---- 突变：全部走本地模型（重新整文序列化 + 引擎写） ----

  const handleToggleSchedule = useCallback(
    (schedule: Schedule) => {
      setDocSchedules((prev) =>
        prev.map((item) =>
          item.id === schedule.id ? { ...item, completed: !item.completed } : item,
        ),
      );
    },
    [setDocSchedules],
  );

  const handleDeleteSchedule = useCallback(
    (schedule: Schedule) => {
      setDocSchedules((prev) => prev.filter((item) => item.id !== schedule.id));
      const key = `delete-${schedule.id}`;
      notification.open({
        key,
        title: '已删除日程',
        description: schedule.title,
        actions: [
          <Button
            type="link"
            size="small"
            key="undo"
            onClick={() => {
              setDocSchedules((prev) =>
                prev.some((item) => item.id === schedule.id) ? prev : [...prev, schedule],
              );
              notification.destroy(key);
            }}
          >
            撤销
          </Button>,
        ],
        duration: 5,
      });
    },
    [setDocSchedules],
  );

  const handleConvertSchedule = useCallback(
    (schedule: Schedule, type: ScheduleType) => {
      setDocSchedules((prev) =>
        prev.map((item) => (item.id === schedule.id ? { ...item, type } : item)),
      );
    },
    [setDocSchedules],
  );

  const handleToggleFocus = useCallback(
    (schedule: Schedule) => {
      const nextFocus = !schedule.focus;
      if (nextFocus) {
        const currentFocusCount = schedules.filter((s) => s.focus).length;
        if (currentFocusCount >= MAX_FOCUS_PER_DAY) {
          message.warning(`每天最多设置 ${MAX_FOCUS_PER_DAY} 个重点日程`);
          return;
        }
      }
      setDocSchedules((prev) =>
        prev.map((item) => (item.id === schedule.id ? { ...item, focus: nextFocus } : item)),
      );
    },
    [schedules, setDocSchedules],
  );

  const handleReorder = useCallback(
    (reordered: Schedule[]) => {
      // 段内行序 = sortOrder（重排写回本地模型）
      const withOrder = reordered.map((item, index) => ({ ...item, sortOrder: index }));
      setDocSchedules(withOrder);
    },
    [setDocSchedules],
  );

  const handleSelectDate = useCallback(
    (date: string) => {
      setInitialLoading(true);
      setCurrentDate(date);
    },
    [setCurrentDate],
  );

  if (initialLoading && docLoading && !model) {
    return <LoadingSpinner tip="加载今日数据..." />;
  }

  const shortWeekday = getWeekday(currentDate).replace('星期', '周');

  return (
    <div className="today-page">
      <div className="today-page-header">
        <div className="today-page-header-left">
          <h1 className="today-page-title">今日</h1>
          <span className="today-page-date">{formatDisplayDate(currentDate)}　{shortWeekday}</span>
          <GreetingSection />
        </div>
      </div>

      <div className="today-workspace">
        <ScheduleBoard
          schedules={schedules}
          periods={schedulePeriods}
          loading={docLoading}
          onOpenCreate={() => {
            setEditTarget(null);
            setScheduleModalOpen(true);
          }}
          onEditSchedule={(schedule) => {
            setScheduleModalOpen(false);
            setEditTarget(schedule);
          }}
          onToggleSchedule={handleToggleSchedule}
          onDeleteSchedule={handleDeleteSchedule}
          onConvertSchedule={handleConvertSchedule}
          onToggleFocus={handleToggleFocus}
          onReorder={handleReorder}
        />
        <aside className="today-page-right" aria-label="今日侧边信息">
          <MiniCalendar
            monthData={currentMonthData}
            loading={calendarLoading}
            onSelectDate={handleSelectDate}
          />
          <QuickNotes date={currentDate} />
        </aside>
      </div>

      <ScheduleFormModal
        currentDate={currentDate}
        open={scheduleModalOpen || editTarget !== null}
        editTarget={editTarget}
        existingSchedules={schedules}
        onCancel={() => {
          setScheduleModalOpen(false);
          setEditTarget(null);
        }}
        onCreated={(schedule) => {
          setScheduleModalOpen(false);
          setEditTarget(null);
          // 新增：追加到本地模型，sortOrder 取当前长度
          setDocSchedules((prev) => [
            ...prev.filter((item) => item.id !== schedule.id),
            { ...schedule, sortOrder: prev.length },
          ]);
        }}
        onUpdated={(schedule) => {
          setScheduleModalOpen(false);
          setEditTarget(null);
          setDocSchedules((prev) =>
            prev.map((item) => (item.id === schedule.id ? schedule : item)),
          );
        }}
      />
    </div>
  );
}
