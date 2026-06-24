import { useCallback, useEffect, useMemo, useState, useTransition, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import {
  Alert,
  Button,
  Empty,
  Input,
  Popover,
  Result,
  Segmented,
  Spin,
  Tag,
  Tooltip,
  message,
} from 'antd';
import {
  CalendarOutlined,
  CheckCircleFilled,
  CheckCircleOutlined,
  ClockCircleOutlined,
  DownOutlined,
  ExclamationCircleOutlined,
  FileMarkdownOutlined,
  LeftOutlined,
  LoadingOutlined,
  MessageOutlined,
  PlusOutlined,
  ReloadOutlined,
  RightOutlined,
  RollbackOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useCurrentDate } from '../../contexts/CurrentDateContext';
import { getVaultEngineSingleton } from '../../services/vault';
import { listVaultFiles } from '../../services/vault/vaultFileBridge';
import {
  appendLocalQuickNote,
  getLocalCalendarMonthOverview,
  getLocalCalendarWeekOverview,
  getLocalDailyMarkdownDocument,
  getReconciledDayDetail,
  saveLocalDailyMarkdownSource,
  type ReconciledDayDetail,
} from '../../services/vault/localCalendarReview';
import { applyConflictResolution, importExternalMd, regenerateMdFromSql } from '../../services/vault/historyReconcile';
import { HistoryConflictAlert } from './HistoryConflictAlert';
import { ScheduleBoard } from '../today/ScheduleBoard';
import { DailyMarkdownModal } from '../review/DailyMarkdownModal';
import { useVaultSync } from '../../hooks/useVaultSync';
import { MARKDOWN_SETTINGS_CHANGED_EVENT, useMarkdownSettings } from '../../hooks/useMarkdownSettings';
import { ROUTES } from '../../shared/constants';
import {
  DEFAULT_SCHEDULE_PERIODS,
  type SchedulePeriod,
} from '../../shared/types/schedulePeriod';
import type {
  CalendarDateMarkerType,
  CalendarDayDetail,
  CalendarDayOverview,
  CalendarMonthOverview,
  CalendarReviewViewMode,
  CalendarWeekOverview,
} from '../../shared/types/calendarReview';
import type { DailyMarkdownDocument } from '../../shared/types/dailyMarkdown';
import { formatDisplayDate, getWeekday } from '../../shared/utils/date';
import { DEFAULT_DAILY_SUBDIRECTORY } from '../../shared/utils/markdownPaths';

const VIEW_OPTIONS: Array<{ label: string; value: CalendarReviewViewMode }> = [
  { label: '日', value: 'day' },
  { label: '周', value: 'week' },
  { label: '月', value: 'month' },
];

const MARKER_LEGEND: Array<{ type: CalendarDateMarkerType; label: string; color: string }> = [
  { type: 'schedule', label: '有日程', color: '#2f6df6' },
  { type: 'quick_note', label: '有快速记录', color: '#8b5cf6' },
  { type: 'review_completed', label: '已复盘', color: '#22c55e' },
  { type: 'review_pending', label: '未复盘', color: '#f59e0b' },
  { type: 'empty', label: '无数据', color: '#cbd5e1' },
];

const WEEK_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

function useLocalCalendarReviewApi() {
  const engine = getVaultEngineSingleton();
  const { vaultRoot } = useVaultSync();
  const { settings } = useMarkdownSettings();
  const dailySubdir = settings?.dailySubdirectory ?? DEFAULT_DAILY_SUBDIRECTORY;

  return useMemo(() => {
    const deps = {
      root: vaultRoot,
      dailySubdir,
      listFiles: () => (vaultRoot ? listVaultFiles(vaultRoot) : Promise.resolve([])),
      readFile: (vaultPath: string) => engine.readLocalFile(vaultPath),
      writeFile: (vaultPath: string, content: string) => engine.onContentChange(vaultPath, content),
    };
    return {
      engine,
      dailySubdir,
      getDayDetail: (date: string) => getReconciledDayDetail(date, deps),
      getWeekOverview: (startDate: string) => getLocalCalendarWeekOverview(startDate, deps),
      getMonthOverview: (month: string) => getLocalCalendarMonthOverview(month, deps),
      appendQuickNote: (date: string, content: string) => appendLocalQuickNote(date, content, deps),
      getMarkdownDocument: (date: string) => getLocalDailyMarkdownDocument(date, deps),
      saveMarkdownSource: (date: string, content: string) => saveLocalDailyMarkdownSource(date, content, deps),
    };
  }, [dailySubdir, engine, vaultRoot]);
}

function getWeekStart(date: string): string {
  const value = dayjs(date);
  return value.subtract((value.day() + 6) % 7, 'day').format('YYYY-MM-DD');
}

function getPeriodTitle(viewMode: CalendarReviewViewMode, date: string): string {
  if (viewMode === 'day') {
    return `${formatDisplayDate(date)}（${getWeekday(date)}）`;
  }
  if (viewMode === 'week') {
    const start = dayjs(getWeekStart(date));
    return `${start.format('YYYY.MM.DD')} - ${start.add(6, 'day').format('YYYY.MM.DD')}`;
  }
  return dayjs(date).format('YYYY年M月');
}

function buildMonthCells(month: string) {
  const monthStart = dayjs(`${month}-01`);
  const leadingDays = (monthStart.day() + 6) % 7;
  const cellCount = Math.ceil((leadingDays + monthStart.daysInMonth()) / 7) * 7;
  const firstCell = monthStart.subtract(leadingDays, 'day');

  return Array.from({ length: cellCount }, (_, index) => {
    const date = firstCell.add(index, 'day');
    return {
      key: date.format('YYYY-MM-DD'),
      date,
      isCurrentMonth: date.format('YYYY-MM') === month,
    };
  });
}

function statusLabel(day: CalendarDayOverview): string {
  if (day.status === 'readonly') return '只读';
  if (day.status === 'no_permission') return '无权限';
  if (day.reviewStatus === 'completed') return '已复盘';
  if (day.scheduleCount > 0 || day.quickNoteCount > 0) return '待复盘';
  return '无数据';
}

function reviewStatusLabel(day?: CalendarDayOverview): string {
  if (!day) return '无数据';
  if (day.reviewStatus === 'completed') return '已复盘';
  if (day.status === 'readonly') return '只读';
  if (day.status === 'no_permission') return '无权限';
  return hasCalendarDayContent(day) ? '未复盘' : '无数据';
}

function reviewStatusTagColor(day?: CalendarDayOverview): 'success' | 'warning' | 'default' {
  if (!day) return 'default';
  if (day.reviewStatus === 'completed') return 'success';
  if (day.status === 'readonly' || day.status === 'no_permission') return 'warning';
  return hasCalendarDayContent(day) ? 'warning' : 'default';
}

function getAnswerPreview(detail: CalendarDayDetail): string {
  const answer = detail.review.review.answers.find((item) => item.content.trim());
  return answer?.content.split('\n').find((line) => line.trim())?.trim() ?? '暂无复盘内容。';
}

function hasCalendarDayContent(day: CalendarDayOverview): boolean {
  return (
    day.scheduleCount > 0 ||
    day.quickNoteCount > 0 ||
    day.reviewStatus === 'completed' ||
    day.markdownStatus === 'ok'
  );
}

function getPeriodOverviewStats(list: CalendarDayOverview[]) {
  return {
    contentDays: list.filter(hasCalendarDayContent).length,
    reviewedDays: list.filter((item) => item.reviewStatus === 'completed').length,
    pendingDays: list.filter((item) => hasCalendarDayContent(item) && item.reviewStatus !== 'completed').length,
    quickNotes: list.reduce((sum, item) => sum + item.quickNoteCount, 0),
  };
}

interface CalendarToolbarProps {
  viewMode: CalendarReviewViewMode;
  currentDate: string;
  pending: boolean;
  onViewModeChange: (value: CalendarReviewViewMode) => void;
  onStep: (offset: number) => void;
  onSelectDate: (date: string) => void;
  onToday: () => void;
}

interface CalendarPeriodPickerProps {
  viewMode: CalendarReviewViewMode;
  currentDate: string;
  onSelectDate: (date: string) => void;
}

function CalendarPeriodPicker({ viewMode, currentDate, onSelectDate }: CalendarPeriodPickerProps) {
  const calendarApi = useLocalCalendarReviewApi();
  const [open, setOpen] = useState(false);
  const [displayMonth, setDisplayMonth] = useState(() => dayjs(currentDate).startOf('month'));
  const [monthOverview, setMonthOverview] = useState<CalendarMonthOverview | null>(null);
  const [loading, setLoading] = useState(false);
  const today = dayjs().format('YYYY-MM-DD');
  const displayMonthKey = displayMonth.format('YYYY-MM');
  const cells = useMemo(() => buildMonthCells(displayMonthKey), [displayMonthKey]);
  const markerMap = useMemo(() => {
    const map = new Map<string, CalendarDayOverview['markers']>();
    for (const day of monthOverview?.list ?? []) {
      map.set(day.date, day.markers);
    }
    return map;
  }, [monthOverview]);

  useEffect(() => {
    if (!open) {
      setDisplayMonth(dayjs(currentDate).startOf('month'));
    }
  }, [currentDate, open]);

  useEffect(() => {
    if (!open) return;

    let cancelled = false;
    setLoading(true);
    calendarApi.getMonthOverview(displayMonthKey)
      .then((res) => {
        if (!cancelled) {
          setMonthOverview(res.success ? res.data : null);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setMonthOverview(null);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [calendarApi, displayMonthKey, open]);

  const handleOpenChange = (nextOpen: boolean) => {
    setOpen(nextOpen);
    if (nextOpen) {
      setDisplayMonth(dayjs(currentDate).startOf('month'));
    }
  };

  const handleSelectDate = (date: string) => {
    onSelectDate(date);
    setOpen(false);
  };

  const picker = (
    <div className="calendar-review-date-picker" aria-label="选择日历回看日期">
      <div className="calendar-review-date-picker-head">
        <strong>{displayMonth.format('YYYY年M月')}</strong>
        <div>
          <button type="button" aria-label="上个月" onClick={() => setDisplayMonth((value) => value.subtract(1, 'month'))}>
            <LeftOutlined />
          </button>
          <button type="button" aria-label="下个月" onClick={() => setDisplayMonth((value) => value.add(1, 'month'))}>
            <RightOutlined />
          </button>
          <button type="button" className="calendar-review-date-picker-today" onClick={() => handleSelectDate(today)}>
            今日
          </button>
        </div>
      </div>

      <div className="calendar-review-date-picker-grid">
        {WEEK_LABELS.map((label) => (
          <span key={label} className="calendar-review-date-picker-weekday">
            {label}
          </span>
        ))}
        {cells.map((cell) => {
          const date = cell.date.format('YYYY-MM-DD');
          const markers = markerMap.get(date) ?? [{ type: 'empty' as const, label: '无数据', color: '#cbd5e1' }];
          const className = [
            'calendar-review-date-picker-day',
            cell.isCurrentMonth ? '' : 'is-outside',
            date === today ? 'is-today' : '',
            date === currentDate ? 'is-selected' : '',
          ]
            .filter(Boolean)
            .join(' ');

          return (
            <button key={cell.key} type="button" className={className} onClick={() => handleSelectDate(date)}>
              <span>{cell.date.date()}</span>
              <i aria-hidden="true">
                {markers.slice(0, 3).map((marker) => (
                  <b key={marker.type} style={{ backgroundColor: marker.color }} title={marker.label} />
                ))}
              </i>
            </button>
          );
        })}
      </div>

      <div className="calendar-review-date-picker-legend">
        {MARKER_LEGEND.map((marker) => (
          <span key={marker.type}>
            <i style={{ backgroundColor: marker.color }} />
            {marker.label}
          </span>
        ))}
      </div>

      {loading && (
        <div className="calendar-review-date-picker-loading" role="status">
          <LoadingOutlined />
          <span>加载月份...</span>
        </div>
      )}
    </div>
  );

  return (
    <Popover
      arrow={false}
      trigger="click"
      placement="bottom"
      open={open}
      onOpenChange={handleOpenChange}
      content={picker}
      overlayClassName="calendar-review-date-popover"
    >
      <button type="button" className="calendar-review-period-trigger" aria-label="选择回看日期">
        <CalendarOutlined />
        <strong>{getPeriodTitle(viewMode, currentDate)}</strong>
        <DownOutlined />
      </button>
    </Popover>
  );
}

function CalendarToolbar({
  viewMode,
  currentDate,
  pending,
  onViewModeChange,
  onStep,
  onSelectDate,
  onToday,
}: CalendarToolbarProps) {
  return (
    <section className="calendar-review-toolbar" aria-label="日历回看工具栏">
      <Segmented
        value={viewMode}
        options={VIEW_OPTIONS}
        onChange={(value) => onViewModeChange(value as CalendarReviewViewMode)}
        className="calendar-review-mode-switch"
      />

      <div className="calendar-review-period-control">
        <Button icon={<LeftOutlined />} onClick={() => onStep(-1)} aria-label="上一个周期" />
        <CalendarPeriodPicker viewMode={viewMode} currentDate={currentDate} onSelectDate={onSelectDate} />
        <Button icon={<RightOutlined />} onClick={() => onStep(1)} aria-label="下一个周期" />
      </div>

      <Button icon={<CalendarOutlined />} onClick={onToday}>
        回到今天
      </Button>

      <div className="calendar-review-legend" aria-label="日期状态说明">
        {MARKER_LEGEND.map((marker) => (
          <span key={marker.type}>
            <i style={{ backgroundColor: marker.color }} />
            {marker.label}
          </span>
        ))}
      </div>

      {pending && (
        <span className="calendar-review-pending">
          <LoadingOutlined />
          切换中
        </span>
      )}
    </section>
  );
}

interface CalendarStatePanelProps {
  status: 'loading' | 'error' | 'empty' | 'no_permission';
  title: string;
  description?: string;
  onRetry?: () => void;
}

function CalendarStatePanel({ status, title, description, onRetry }: CalendarStatePanelProps) {
  if (status === 'loading') {
    return (
      <div className="calendar-review-state">
        <div className="calendar-review-loading-card" role="status">
          <Spin size="large" />
          <span>{title}</span>
        </div>
      </div>
    );
  }

  const icon = status === 'error' ? <ExclamationCircleOutlined /> : undefined;
  const resultStatus = status === 'error' ? 'error' : status === 'no_permission' ? 'warning' : 'info';

  return (
    <div className="calendar-review-state">
      <Result
        status={resultStatus}
        icon={icon}
        title={title}
        subTitle={description}
        extra={
          onRetry ? (
            <Button type="primary" icon={<ReloadOutlined />} onClick={onRetry}>
              重试
            </Button>
          ) : null
        }
      />
    </div>
  );
}

interface DayReviewViewProps {
  detail: CalendarDayDetail;
  periods: SchedulePeriod[];
  quickNoteCreating: boolean;
  markdownDocument: DailyMarkdownDocument | null;
  markdownLoading: boolean;
  markdownSaving: boolean;
  markdownError: string | null;
  markdownModalOpen: boolean;
  onCreateQuickNote: (content: string) => Promise<boolean>;
  onOpenReview: () => void;
  onOpenMarkdown: () => void;
  onCloseMarkdown: () => void;
  onSaveMarkdownSource: (content: string) => Promise<DailyMarkdownDocument | null>;
  onUnavailable: (feature: string) => void;
}

function DayReviewView({
  detail,
  periods,
  quickNoteCreating,
  markdownDocument,
  markdownLoading,
  markdownSaving,
  markdownError,
  markdownModalOpen,
  onCreateQuickNote,
  onOpenReview,
  onOpenMarkdown,
  onCloseMarkdown,
  onSaveMarkdownSource,
  onUnavailable,
}: DayReviewViewProps) {
  const [composerOpen, setComposerOpen] = useState(false);
  const [noteDraft, setNoteDraft] = useState('');
  const overview = detail.overview;
  const canBackfillQuickNote = detail.permissions.canBackfillQuickNote;
  const quickNoteDisabledReason = detail.permissions.reason ?? '当前日期暂不可补充快速记录';

  useEffect(() => {
    setComposerOpen(false);
    setNoteDraft('');
  }, [overview.date]);

  const handleSubmitQuickNote = async () => {
    const saved = await onCreateQuickNote(noteDraft);
    if (saved) {
      setNoteDraft('');
      setComposerOpen(false);
    }
  };

  return (
    <div className="calendar-day-view">
      {overview.status === 'readonly' && (
        <Alert
          type="warning"
          showIcon
          className="calendar-review-alert"
          message={detail.permissions.reason ?? '当前日期为只读演示场景，可查看但不可修改。'}
        />
      )}

      <div className="calendar-day-layout">
        <section className="calendar-day-schedule">
          <ScheduleBoard
            schedules={detail.schedules}
            periods={periods}
            title="日程安排"
            addButtonText="新建日程"
            focusEmptyText="这一天没有标记为重点的日程。"
            readonly
            showTodoPanel={false}
            onOpenCreate={() => onUnavailable('历史日程编辑')}
          />
        </section>

        <aside className="calendar-day-side">
          <section className="calendar-review-card calendar-date-status-card">
            <div className="calendar-card-heading">
              <div>
                <h2>{formatDisplayDate(overview.date)}</h2>
                <p>
                  {overview.weekday} · 农历 {overview.lunarLabel}
                </p>
              </div>
              <Tag color={reviewStatusTagColor(overview)}>{reviewStatusLabel(overview)}</Tag>
            </div>
            <div className="calendar-status-tags">
              {overview.markers.map((marker) => (
                <span key={marker.type} style={{ '--marker-color': marker.color } as CSSProperties}>
                  <i />
                  {marker.label}
                  {marker.count ? ` ${marker.count}` : ''}
                </span>
              ))}
            </div>
          </section>

          <section className="calendar-review-card">
            <div className="calendar-card-heading">
              <div>
                <h3>
                  <MessageOutlined />
                  快速记录
                </h3>
                <p>{detail.quickNotes.length} 条记录</p>
              </div>
              <Tooltip title={!canBackfillQuickNote ? quickNoteDisabledReason : ''}>
                <span>
                  <Button
                    size="small"
                    icon={<PlusOutlined />}
                    disabled={!canBackfillQuickNote}
                    onClick={() => setComposerOpen(true)}
                  >
                    补充记录
                  </Button>
                </span>
              </Tooltip>
            </div>

            {composerOpen && (
              <div className="calendar-quick-note-composer">
                <Input.TextArea
                  autoFocus
                  value={noteDraft}
                  placeholder="补充这一天发生的事情、灵感或结论..."
                  disabled={quickNoteCreating}
                  autoSize={{ minRows: 4, maxRows: 8 }}
                  maxLength={800}
                  showCount
                  onChange={(event) => setNoteDraft(event.target.value)}
                />
                <div>
                  <Button
                    size="small"
                    disabled={quickNoteCreating}
                    onClick={() => {
                      setComposerOpen(false);
                      setNoteDraft('');
                    }}
                  >
                    取消
                  </Button>
                  <Button
                    type="primary"
                    size="small"
                    loading={quickNoteCreating}
                    disabled={!noteDraft.trim()}
                    onClick={() => void handleSubmitQuickNote()}
                  >
                    保存
                  </Button>
                </div>
              </div>
            )}

            {detail.quickNotes.length === 0 ? (
              <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="这一天暂无快速记录" />
            ) : (
              <div className="calendar-quick-note-list">
                {detail.quickNotes.slice(0, 5).map((note) => (
                  <article key={note.id} className="calendar-quick-note-item">
                    <time>{dayjs(note.createdAt).format('HH:mm')}</time>
                    <p>{note.content}</p>
                  </article>
                ))}
              </div>
            )}
          </section>

          <section className="calendar-review-card">
            <div className="calendar-card-heading">
              <div>
                <h3>
                  <CheckCircleOutlined />
                  复盘内容
                </h3>
                <p>{detail.review.scheme.name}</p>
              </div>
              <Button
                size="small"
                type={detail.review.review.status === 'completed' ? 'default' : 'primary'}
                disabled={!detail.permissions.canEditReview}
                onClick={onOpenReview}
              >
                {detail.review.review.status === 'completed' ? '查看复盘' : '去补写'}
              </Button>
            </div>
            <div className="calendar-review-answer-preview">
              <p>{getAnswerPreview(detail)}</p>
            </div>
          </section>

          <section className="calendar-review-card">
            <div className="calendar-card-heading">
              <div>
                <h3>
                  <FileMarkdownOutlined />
                  Markdown 文档
                </h3>
                <p>{detail.markdown.relativePath}</p>
              </div>
              <Tag color={detail.markdown.status === 'ok' ? 'success' : 'default'}>
                {detail.markdown.status === 'ok' ? '可查看' : detail.markdown.status}
              </Tag>
            </div>
            <div className="calendar-markdown-actions">
              <Button
                icon={<FileMarkdownOutlined />}
                disabled={!detail.permissions.canViewMarkdown}
                loading={markdownLoading}
                onClick={onOpenMarkdown}
              >
                预览
              </Button>
              <Button onClick={() => onUnavailable('文档库管理')}>打开所在文档库</Button>
            </div>
            {detail.markdown.permissions.reason && (
              <p className="calendar-card-muted">{detail.markdown.permissions.reason}</p>
            )}
          </section>
        </aside>
      </div>

      <DailyMarkdownModal
        open={markdownModalOpen}
        document={markdownDocument}
        loading={markdownLoading}
        saving={markdownSaving}
        error={markdownError}
        onClose={onCloseMarkdown}
        onSaveSource={onSaveMarkdownSource}
      />
    </div>
  );
}

interface WeekReviewViewProps {
  data: CalendarWeekOverview;
  selectedDate: string;
  selectedDayDetail: CalendarDayDetail | null;
  selectedDayLoading: boolean;
  selectedDayError: string | null;
  onSelectDate: (date: string) => void;
  onRetrySelectedDay: () => void;
  onOpenDayReview: () => void;
}

function WeekReviewView({
  data,
  selectedDate,
  selectedDayDetail,
  selectedDayLoading,
  selectedDayError,
  onSelectDate,
  onRetrySelectedDay,
  onOpenDayReview,
}: WeekReviewViewProps) {
  const stats = getPeriodOverviewStats(data.list);

  return (
    <div className="calendar-week-view">
      <section className="calendar-week-summary-card" aria-label="本周概览">
        <div className="calendar-week-summary-heading">
          <div>
            <h2>本周概览</h2>
            <p>{dayjs(data.startDate).format('MM.DD')} - {dayjs(data.endDate).format('MM.DD')}</p>
          </div>
          <Tag color={data.status === 'ok' ? 'processing' : data.status === 'empty' ? 'default' : 'warning'}>
            {data.total} 天
          </Tag>
        </div>

        <div className="calendar-week-summary">
          <article>
            <CalendarOutlined />
            <strong>{stats.contentDays}</strong>
            <span>本周有内容天数</span>
          </article>
          <article>
            <CheckCircleFilled />
            <strong>{stats.reviewedDays}</strong>
            <span>已复盘天数</span>
          </article>
          <article>
            <ClockCircleOutlined />
            <strong>{stats.pendingDays}</strong>
            <span>未复盘天数</span>
          </article>
          <article>
            <MessageOutlined />
            <strong>{stats.quickNotes}</strong>
            <span>快速记录条数</span>
          </article>
        </div>
      </section>

      <div className="calendar-week-content">
        <div className="calendar-week-grid">
          {data.list.map((day) => {
            const active = day.date === selectedDate;
            return (
              <button
                key={day.date}
                type="button"
                className={`calendar-week-card${active ? ' is-active' : ''}${day.status === 'empty' ? ' is-empty' : ''}`}
                onClick={() => onSelectDate(day.date)}
              >
                <div className="calendar-week-card-head">
                  <strong>{day.weekday.replace('星期', '周')}</strong>
                  <span>{dayjs(day.date).format('MM.DD')}</span>
                </div>
                <div className="calendar-week-section">
                  <h4>
                    <CalendarOutlined />
                    日程 <Tag>{day.scheduleCount}</Tag>
                  </h4>
                  {day.schedulePreview.length === 0 ? (
                    <p className="calendar-week-empty-line">暂无日程</p>
                  ) : (
                    day.schedulePreview.map((schedule) => (
                      <p key={schedule.id}>
                        <time>{schedule.startTime}-{schedule.endTime}</time>
                        {schedule.title}
                      </p>
                    ))
                  )}
                </div>
                <div className="calendar-week-section">
                  <h4>
                    <MessageOutlined />
                    快速记录 <Tag>{day.quickNoteCount}</Tag>
                  </h4>
                  {day.quickNotePreview.length === 0 ? (
                    <p className="calendar-week-empty-line">暂无记录</p>
                  ) : (
                    day.quickNotePreview.map((note) => (
                      <p key={note.id}>
                        <time>{note.time}</time>
                        {note.content}
                      </p>
                    ))
                  )}
                </div>
                <div className="calendar-week-status">
                  {day.markers.map((marker) => (
                    <i key={marker.type} style={{ backgroundColor: marker.color }} title={marker.label} />
                  ))}
                  <span>{statusLabel(day)}</span>
                </div>
              </button>
            );
          })}
        </div>

        <SelectedDayDetailPanel
          detail={selectedDayDetail}
          loading={selectedDayLoading}
          error={selectedDayError}
          fallbackDate={selectedDate}
          onRetry={onRetrySelectedDay}
          onOpenDayReview={onOpenDayReview}
        />
      </div>
    </div>
  );
}

interface MonthReviewViewProps {
  data: CalendarMonthOverview;
  selectedDate: string;
  selectedDayDetail: CalendarDayDetail | null;
  selectedDayLoading: boolean;
  selectedDayError: string | null;
  onSelectDate: (date: string) => void;
  onRetrySelectedDay: () => void;
  onOpenDayReview: () => void;
}

function MonthReviewView({
  data,
  selectedDate,
  selectedDayDetail,
  selectedDayLoading,
  selectedDayError,
  onSelectDate,
  onRetrySelectedDay,
  onOpenDayReview,
}: MonthReviewViewProps) {
  const dayMap = useMemo(
    () => new Map(data.list.map((day) => [day.date, day])),
    [data.list],
  );
  const cells = useMemo(() => buildMonthCells(data.month), [data.month]);
  const selectedDay = dayMap.get(selectedDate);
  const stats = getPeriodOverviewStats(data.list);

  return (
    <div className="calendar-month-view">
      <section className="calendar-week-summary-card calendar-month-summary-card" aria-label="本月概览">
        <div className="calendar-week-summary-heading">
          <div>
            <h2>本月概览</h2>
            <p>{dayjs(data.month).format('YYYY年M月')}</p>
          </div>
          <Tag color={data.status === 'ok' ? 'processing' : data.status === 'empty' ? 'default' : 'warning'}>
            {data.total} 天
          </Tag>
        </div>

        <div className="calendar-week-summary">
          <article>
            <CalendarOutlined />
            <strong>{stats.contentDays}</strong>
            <span>本月有内容天数</span>
          </article>
          <article>
            <CheckCircleFilled />
            <strong>{stats.reviewedDays}</strong>
            <span>已复盘天数</span>
          </article>
          <article>
            <ClockCircleOutlined />
            <strong>{stats.pendingDays}</strong>
            <span>未复盘天数</span>
          </article>
          <article>
            <MessageOutlined />
            <strong>{stats.quickNotes}</strong>
            <span>快速记录条数</span>
          </article>
        </div>
      </section>

      <section className="calendar-month-board">
        <div className="calendar-month-weekdays">
          {WEEK_LABELS.map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
        <div className="calendar-month-grid">
          {cells.map((cell) => {
            const date = cell.date.format('YYYY-MM-DD');
            const day = dayMap.get(date);
            const active = date === selectedDate;
            return (
              <button
                key={cell.key}
                type="button"
                className={`calendar-month-day${cell.isCurrentMonth ? '' : ' is-outside'}${active ? ' is-active' : ''}`}
                onClick={() => onSelectDate(date)}
              >
                <strong>{cell.date.date()}</strong>
                <span>{day?.lunarLabel ?? ''}</span>
                <div className="calendar-month-markers">
                  {(day?.markers ?? [{ type: 'empty' as const, label: '无数据', color: '#cbd5e1' }]).slice(0, 4).map((marker) => (
                    <i key={marker.type} style={{ backgroundColor: marker.color }} title={marker.label} />
                  ))}
                </div>
              </button>
            );
          })}
        </div>
      </section>

      <SelectedDayDetailPanel
        detail={selectedDayDetail}
        loading={selectedDayLoading}
        error={selectedDayError}
        fallbackDate={selectedDay?.date ?? selectedDate}
        onRetry={onRetrySelectedDay}
        onOpenDayReview={onOpenDayReview}
      />
    </div>
  );
}

interface SelectedDayDetailPanelProps {
  detail: CalendarDayDetail | null;
  loading: boolean;
  error: string | null;
  fallbackDate: string;
  onRetry: () => void;
  onOpenDayReview: () => void;
}

function SelectedDayDetailPanel({
  detail,
  loading,
  error,
  fallbackDate,
  onRetry,
  onOpenDayReview,
}: SelectedDayDetailPanelProps) {
  if (loading) {
    return (
      <aside className="calendar-selected-day-side">
        <section className="calendar-review-card calendar-selected-day-card">
          <div className="calendar-card-heading">
            <div>
              <h2>查看当天详情</h2>
              <p>{formatDisplayDate(fallbackDate)}</p>
            </div>
          </div>
          <div className="calendar-selected-day-loading" role="status">
            <Spin />
            <span>正在加载当天详情</span>
          </div>
        </section>
      </aside>
    );
  }

  if (error) {
    return (
      <aside className="calendar-selected-day-side">
        <section className="calendar-review-card calendar-selected-day-card">
          <div className="calendar-card-heading">
            <div>
              <h2>查看当天详情</h2>
              <p>{formatDisplayDate(fallbackDate)}</p>
            </div>
          </div>
          <Alert
            type="error"
            showIcon
            message="当天详情加载失败"
            description={error}
            action={
              <Button size="small" icon={<ReloadOutlined />} onClick={onRetry}>
                重试
              </Button>
            }
          />
        </section>
      </aside>
    );
  }

  if (!detail) {
    return (
      <aside className="calendar-selected-day-side">
        <section className="calendar-review-card calendar-selected-day-card">
          <div className="calendar-card-heading">
            <div>
              <h2>查看当天详情</h2>
              <p>{formatDisplayDate(fallbackDate)}</p>
            </div>
          </div>
          <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="请选择一个日期查看详情" />
        </section>
      </aside>
    );
  }

  const overview = detail.overview;

  return (
    <aside className="calendar-selected-day-side">
      <section className="calendar-review-card calendar-selected-day-card">
        <div className="calendar-card-heading">
          <div>
            <span className="calendar-selected-day-kicker">查看当天详情</span>
            <h2>{formatDisplayDate(overview.date || fallbackDate)}</h2>
            <p>{overview.weekday} · 农历 {overview.lunarLabel}</p>
          </div>
          <Tag color={reviewStatusTagColor(overview)}>{reviewStatusLabel(overview)}</Tag>
        </div>

        <div className="calendar-status-tags calendar-selected-day-tags">
          {overview.markers.map((marker) => (
            <span key={marker.type} style={{ '--marker-color': marker.color } as CSSProperties}>
              <i />
              {marker.label}
              {marker.count ? ` ${marker.count}` : ''}
            </span>
          ))}
        </div>

        <div className="calendar-selected-day-stats">
          <span>
            <CalendarOutlined />
            {detail.schedules.length} 个日程
          </span>
          <span>
            <MessageOutlined />
            {detail.quickNotes.length} 条记录
          </span>
          <span>
            <CheckCircleOutlined />
            {reviewStatusLabel(overview)}
          </span>
        </div>

        <div className="calendar-selected-day-section">
          <h3>日程安排</h3>
          {detail.schedules.length === 0 ? (
            <p className="calendar-week-empty-line">当天暂无日程。</p>
          ) : (
            detail.schedules.slice(0, 4).map((schedule) => (
              <p key={schedule.id}>
                <time>{schedule.startTime}-{schedule.endTime}</time>
                {schedule.title}
              </p>
            ))
          )}
        </div>

        <div className="calendar-selected-day-section">
          <h3>快速记录</h3>
          {detail.quickNotes.length === 0 ? (
            <p className="calendar-week-empty-line">当天暂无快速记录。</p>
          ) : (
            detail.quickNotes.slice(0, 3).map((note) => (
              <p key={note.id}>
                <time>{dayjs(note.createdAt).format('HH:mm')}</time>
                {note.content}
              </p>
            ))
          )}
        </div>

        <div className="calendar-selected-day-section">
          <h3>复盘摘要</h3>
          <p>{getAnswerPreview(detail)}</p>
        </div>

        <Button type="primary" block onClick={onOpenDayReview}>
          查看完整日回看
        </Button>
      </section>
    </aside>
  );
}

export function CalendarReviewPage() {
  const navigate = useNavigate();
  const { currentDate, setCurrentDate, goToToday } = useCurrentDate();
  const { vaultRoot } = useVaultSync();
  const calendarApi = useLocalCalendarReviewApi();
  const [viewMode, setViewMode] = useState<CalendarReviewViewMode>('day');
  const [isPending, startTransition] = useTransition();
  const [periods] = useState<SchedulePeriod[]>(DEFAULT_SCHEDULE_PERIODS);
  const [dayDetail, setDayDetail] = useState<ReconciledDayDetail | null>(null);
  const [reconciling, setReconciling] = useState(false);
  const [weekData, setWeekData] = useState<CalendarWeekOverview | null>(null);
  const [monthData, setMonthData] = useState<CalendarMonthOverview | null>(null);
  const [selectedDayDetail, setSelectedDayDetail] = useState<CalendarDayDetail | null>(null);
  const [selectedDayLoading, setSelectedDayLoading] = useState(false);
  const [selectedDayError, setSelectedDayError] = useState<string | null>(null);
  const [selectedDayRefreshSignal, setSelectedDayRefreshSignal] = useState(0);
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [error, setError] = useState<string | null>(null);
  const [refreshSignal, setRefreshSignal] = useState(0);
  const [quickNoteCreating, setQuickNoteCreating] = useState(false);
  const [markdownModalOpen, setMarkdownModalOpen] = useState(false);
  const [markdownDocument, setMarkdownDocument] = useState<DailyMarkdownDocument | null>(null);
  const [markdownLoading, setMarkdownLoading] = useState(false);
  const [markdownSaving, setMarkdownSaving] = useState(false);
  const [markdownError, setMarkdownError] = useState<string | null>(null);

  const selectedMonth = dayjs(currentDate).format('YYYY-MM');
  const selectedWeekStart = getWeekStart(currentDate);
  const overviewRequestKey =
    viewMode === 'day' ? currentDate : viewMode === 'week' ? selectedWeekStart : selectedMonth;

  const refetch = useCallback(() => {
    setRefreshSignal((value) => value + 1);
  }, []);

  /** 对账冲突解决（docs/09 §8.3 整单拍板）。 */
  const handleResolve = useCallback(
    async (action: 'keep_sql' | 'keep_md' | 'regenerate' | 'import') => {
      if (!vaultRoot) return;
      setReconciling(true);
      try {
        if (action === 'keep_sql') await applyConflictResolution(vaultRoot, currentDate, 'keep_sql');
        else if (action === 'keep_md') await applyConflictResolution(vaultRoot, currentDate, 'keep_md');
        else if (action === 'regenerate') await regenerateMdFromSql(vaultRoot, currentDate);
        else if (action === 'import') await importExternalMd(vaultRoot, currentDate);
        message.success('已同步');
        refetch();
        setSelectedDayRefreshSignal((value) => value + 1);
      } catch {
        message.error('同步失败，请稍后重试');
      } finally {
        setReconciling(false);
      }
    },
    [vaultRoot, currentDate, refetch],
  );

  useEffect(() => {
    const off = calendarApi.engine.onFileChanged((paths) => {
      if (paths.some((path) => path.startsWith(`${calendarApi.dailySubdir}/`))) {
        refetch();
        setSelectedDayRefreshSignal((value) => value + 1);
      }
    });
    return off;
  }, [calendarApi, refetch]);

  useEffect(() => {
    const handler = () => {
      refetch();
      setSelectedDayRefreshSignal((value) => value + 1);
    };
    window.addEventListener(MARKDOWN_SETTINGS_CHANGED_EVENT, handler);
    return () => window.removeEventListener(MARKDOWN_SETTINGS_CHANGED_EVENT, handler);
  }, [refetch]);

  useEffect(() => {
    let cancelled = false;
    const requestKey = overviewRequestKey;
    setStatus('loading');
    setError(null);

    const load = async () => {
      try {
        if (viewMode === 'day') {
          const res = await calendarApi.getDayDetail(requestKey);
          if (cancelled) return;
          setDayDetail(res.data);
          if (!res.success) {
            setError(res.message || '日回看数据加载失败');
            setStatus('error');
            return;
          }
          setStatus('success');
          return;
        }

        if (viewMode === 'week') {
          const res = await calendarApi.getWeekOverview(requestKey);
          if (cancelled) return;
          if (!res.success) {
            setError(res.message || '周回看数据加载失败');
            setStatus('error');
            return;
          }
          setWeekData(res.data);
          setStatus('success');
          return;
        }

        const res = await calendarApi.getMonthOverview(requestKey);
        if (cancelled) return;
        if (!res.success) {
          setError(res.message || '月回看数据加载失败');
          setStatus('error');
          return;
        }
        setMonthData(res.data);
        setStatus('success');
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : '日历回看数据加载失败');
        setStatus('error');
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [calendarApi, overviewRequestKey, refreshSignal, viewMode]);

  useEffect(() => {
    if (viewMode === 'day') {
      return;
    }

    let cancelled = false;
    setSelectedDayLoading(true);
    setSelectedDayError(null);
    setSelectedDayDetail(null);

    calendarApi.getDayDetail(currentDate)
      .then((res) => {
        if (cancelled) {
          return;
        }
        setSelectedDayDetail(res.data);
        if (!res.success && !res.data) {
          setSelectedDayError(res.message || '当天详情加载失败');
        }
      })
      .catch((err) => {
        if (cancelled) {
          return;
        }
        setSelectedDayDetail(null);
        setSelectedDayError(err instanceof Error ? err.message : '当天详情加载失败');
      })
      .finally(() => {
        if (!cancelled) {
          setSelectedDayLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [calendarApi, currentDate, selectedDayRefreshSignal, viewMode]);

  const handleViewModeChange = useCallback((nextMode: CalendarReviewViewMode) => {
    startTransition(() => {
      setViewMode(nextMode);
    });
  }, []);

  const handleStep = useCallback(
    (offset: number) => {
      const unit = viewMode === 'day' ? 'day' : viewMode === 'week' ? 'week' : 'month';
      const nextDate = dayjs(currentDate).add(offset, unit).format('YYYY-MM-DD');
      startTransition(() => setCurrentDate(nextDate));
    },
    [currentDate, setCurrentDate, viewMode],
  );

  const handleToday = useCallback(() => {
    startTransition(() => goToToday());
  }, [goToToday]);

  const handleSelectPeriodDate = useCallback(
    (date: string) => {
      startTransition(() => {
        setCurrentDate(date);
      });
    },
    [setCurrentDate],
  );

  const handleRetrySelectedDay = useCallback(() => {
    setSelectedDayRefreshSignal((value) => value + 1);
  }, []);

  const handleOpenSelectedDayReview = useCallback(() => {
    startTransition(() => {
      setViewMode('day');
    });
  }, []);

  const handleCreateQuickNote = useCallback(
    async (content: string) => {
      const trimmed = content.trim();
      if (!trimmed) {
        return false;
      }
      if (!dayDetail?.permissions.canBackfillQuickNote) {
        message.info(dayDetail?.permissions.reason ?? '当前日期暂不可补充快速记录');
        return false;
      }

      setQuickNoteCreating(true);
      try {
        const res = await calendarApi.appendQuickNote(currentDate, trimmed);
        if (!res.success || !res.data) {
          message.error(res.message || '快速记录保存失败');
          return false;
        }
        message.success(res.message || '记录已保存');
        refetch();
        return true;
      } catch {
        message.error('快速记录保存失败');
        return false;
      } finally {
        setQuickNoteCreating(false);
      }
    },
    [calendarApi, currentDate, dayDetail?.permissions.canBackfillQuickNote, dayDetail?.permissions.reason, refetch],
  );

  const handleOpenReview = useCallback(() => {
    navigate(ROUTES.REVIEW);
  }, [navigate]);

  const handleOpenMarkdown = useCallback(async () => {
    if (!dayDetail?.permissions.canViewMarkdown) {
      message.info(dayDetail?.permissions.reason ?? '当前日期暂不可查看 Markdown');
      return;
    }
    setMarkdownModalOpen(true);
    setMarkdownLoading(true);
    setMarkdownError(null);
    try {
      const currentDocument = await calendarApi.getMarkdownDocument(currentDate);
      if (currentDocument.success && currentDocument.data) {
        setMarkdownDocument(currentDocument.data);
        return;
      }
      setMarkdownDocument(currentDocument.data ?? null);
      setMarkdownError(currentDocument.message || 'Markdown 文档加载失败');
    } catch (err) {
      setMarkdownDocument(null);
      setMarkdownError(err instanceof Error ? err.message : 'Markdown 文档加载失败');
    } finally {
      setMarkdownLoading(false);
    }
  }, [calendarApi, currentDate, dayDetail?.permissions.canViewMarkdown, dayDetail?.permissions.reason]);

  const handleSaveMarkdownSource = useCallback(
    async (content: string) => {
      setMarkdownSaving(true);
      try {
        const res = await calendarApi.saveMarkdownSource(currentDate, content);
        setMarkdownDocument(res.data);
        if (!res.success) {
          message.error(res.message || 'Markdown 源码保存失败');
          return null;
        }
        message.success('Markdown 源码已保存');
        refetch();
        return res.data;
      } catch {
        message.error('Markdown 源码保存失败');
        return null;
      } finally {
        setMarkdownSaving(false);
      }
    },
    [calendarApi, currentDate, refetch],
  );

  const handleUnavailable = useCallback((feature: string) => {
    message.info(`${feature} 暂未开发`);
  }, []);

  const renderBody = () => {
    if (status === 'loading') {
      return <CalendarStatePanel status="loading" title="正在加载日历回看..." />;
    }
    if (status === 'error') {
      return (
        <CalendarStatePanel
          status="error"
          title="日历回看加载失败"
          description={error ?? '请稍后重试'}
          onRetry={refetch}
        />
      );
    }

    if (viewMode === 'day') {
      if (!dayDetail) {
        return <CalendarStatePanel status="empty" title="暂无日期详情" />;
      }
      if (!dayDetail.permissions.canView) {
        return (
          <CalendarStatePanel
            status="no_permission"
            title="暂无查看权限"
            description={dayDetail.permissions.reason}
          />
        );
      }
      return (
        <>
        {dayDetail.reconciliationStatus !== 'in_sync' && dayDetail.reconciliationStatus !== 'empty' && (
          <HistoryConflictAlert
            status={dayDetail.reconciliationStatus}
            date={currentDate}
            busy={reconciling}
            onResolve={handleResolve}
          />
        )}
        <DayReviewView
          detail={dayDetail}
          periods={periods}
          quickNoteCreating={quickNoteCreating}
          markdownDocument={markdownDocument}
          markdownLoading={markdownLoading}
          markdownSaving={markdownSaving}
          markdownError={markdownError}
          markdownModalOpen={markdownModalOpen}
          onCreateQuickNote={handleCreateQuickNote}
          onOpenReview={handleOpenReview}
          onOpenMarkdown={handleOpenMarkdown}
          onCloseMarkdown={() => setMarkdownModalOpen(false)}
          onSaveMarkdownSource={handleSaveMarkdownSource}
          onUnavailable={handleUnavailable}
        />
        </>
      );
    }

    if (viewMode === 'week') {
      return weekData ? (
        <WeekReviewView
          data={weekData}
          selectedDate={currentDate}
          selectedDayDetail={selectedDayDetail}
          selectedDayLoading={selectedDayLoading}
          selectedDayError={selectedDayError}
          onSelectDate={handleSelectPeriodDate}
          onRetrySelectedDay={handleRetrySelectedDay}
          onOpenDayReview={handleOpenSelectedDayReview}
        />
      ) : (
        <CalendarStatePanel status="empty" title="暂无周回看数据" />
      );
    }

    return monthData ? (
      <MonthReviewView
        data={monthData}
        selectedDate={currentDate}
        selectedDayDetail={selectedDayDetail}
        selectedDayLoading={selectedDayLoading}
        selectedDayError={selectedDayError}
        onSelectDate={handleSelectPeriodDate}
        onRetrySelectedDay={handleRetrySelectedDay}
        onOpenDayReview={handleOpenSelectedDayReview}
      />
    ) : (
      <CalendarStatePanel status="empty" title="暂无月回看数据" />
    );
  };

  return (
    <div className="calendar-review-page">
      <div className="calendar-review-header">
        <div>
          <h1>日历回看</h1>
          <p>按日、周、月回看历史日期，查看日程、快速记录、复盘与 Markdown 文档。</p>
        </div>
        <Button icon={<RollbackOutlined />} onClick={() => navigate(ROUTES.TODAY)}>
          返回今日
        </Button>
      </div>

      <CalendarToolbar
        viewMode={viewMode}
        currentDate={currentDate}
        pending={isPending}
        onViewModeChange={handleViewModeChange}
        onStep={handleStep}
        onSelectDate={handleSelectPeriodDate}
        onToday={handleToday}
      />

      {renderBody()}
    </div>
  );
}
