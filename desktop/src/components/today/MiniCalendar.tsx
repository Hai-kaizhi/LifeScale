import { useMemo } from 'react';
import dayjs from 'dayjs';
import { LeftOutlined, LoadingOutlined, RightOutlined } from '@ant-design/icons';
import { useCurrentDate } from '../../contexts/CurrentDateContext';
import type { CalendarMarker, CalendarMarkerType, CalendarMonth } from '../../shared/types/calendar';

const WEEK_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

const MARKER_LEGEND: Array<{ type: CalendarMarkerType; label: string }> = [
  { type: 'schedule', label: '日程' },
  { type: 'review', label: '复盘' },
];

interface MiniCalendarProps {
  monthData?: CalendarMonth;
  loading?: boolean;
  onSelectDate: (date: string) => void;
}

function getMarkerColor(type: CalendarMarkerType): string {
  if (type === 'schedule') return '#22c55e';
  return '#7c3aed';
}

function buildCalendarCells(monthDate: dayjs.Dayjs) {
  const monthStart = monthDate.startOf('month');
  const leadingDays = (monthStart.day() + 6) % 7;
  const cellCount = Math.ceil((leadingDays + monthDate.daysInMonth()) / 7) * 7;
  const firstCell = monthStart.subtract(leadingDays, 'day');

  return Array.from({ length: cellCount }, (_, index) => {
    const date = firstCell.add(index, 'day');
    return {
      key: date.format('YYYY-MM-DD'),
      date,
      isCurrentMonth: date.month() === monthDate.month(),
    };
  });
}

export function MiniCalendar({ monthData, loading = false, onSelectDate }: MiniCalendarProps) {
  const { currentDate } = useCurrentDate();
  const current = dayjs(currentDate);
  const currentMonth = current.format('YYYY-MM');
  const today = dayjs().format('YYYY-MM-DD');

  const calendarCells = useMemo(() => buildCalendarCells(current), [currentMonth]);
  const markerMap = useMemo(() => {
    const map = new Map<string, CalendarMarker[]>();
    for (const day of monthData?.days ?? []) {
      const markers = day.markers.map((marker) => ({
        ...marker,
        date: day.date,
      }));
      if (markers.length > 0) {
        map.set(day.date, markers);
      }
    }
    return map;
  }, [monthData]);

  const goToMonth = (offset: number) => {
    onSelectDate(current.add(offset, 'month').format('YYYY-MM-DD'));
  };

  return (
    <div className="mini-calendar" aria-busy={loading}>
      <div className="mini-calendar-header">
        <span className="mini-calendar-month">{current.format('YYYY年M月')}</span>
        <div className="mini-calendar-controls">
          <button type="button" aria-label="上个月" onClick={() => goToMonth(-1)}>
            <LeftOutlined />
          </button>
          <button type="button" aria-label="下个月" onClick={() => goToMonth(1)}>
            <RightOutlined />
          </button>
          <button
            type="button"
            className="mini-calendar-today-btn"
            aria-label="回到今天"
            onClick={() => onSelectDate(today)}
          >
            今日
          </button>
        </div>
      </div>

      <div className="mini-calendar-grid">
        {WEEK_LABELS.map((label) => (
          <div key={label} className="mini-calendar-weekday">
            {label}
          </div>
        ))}
        {calendarCells.map((cell) => {
          const dateStr = cell.date.format('YYYY-MM-DD');
          const markers = markerMap.get(dateStr) ?? [];
          const className = [
            'mini-calendar-day',
            cell.isCurrentMonth ? '' : 'outside',
            dateStr === today ? 'today' : '',
            dateStr === currentDate ? 'selected' : '',
          ]
            .filter(Boolean)
            .join(' ');

          return (
            <button
              type="button"
              key={cell.key}
              className={className}
              onClick={() => onSelectDate(dateStr)}
            >
              <span className="mini-calendar-day-number">{cell.date.date()}</span>
              <span className="mini-calendar-markers" aria-hidden="true">
                {markers.slice(0, 3).map((marker, index) => (
                  <span
                    key={`${marker.type}-${index}`}
                    className="mini-calendar-marker"
                    style={{ backgroundColor: marker.color }}
                  />
                ))}
              </span>
            </button>
          );
        })}
      </div>

      <div className="mini-calendar-legend" aria-label="月历标记说明">
        {MARKER_LEGEND.map((item) => (
          <span key={item.type} className="mini-calendar-legend-item">
            <span style={{ backgroundColor: getMarkerColor(item.type) }} />
            {item.label}
          </span>
        ))}
      </div>

      {loading && (
        <div className="mini-calendar-loading" role="status">
          <LoadingOutlined />
          <span>加载月份...</span>
        </div>
      )}
    </div>
  );
}
