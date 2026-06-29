import { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Button, Input, Modal, Popover, Spin, Tooltip } from 'antd';
import {
  CalendarOutlined,
  DeleteOutlined,
  DownOutlined,
  EditOutlined,
  ExclamationCircleFilled,
  LeftOutlined,
  LoadingOutlined,
  RightOutlined,
  ThunderboltOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useQuickNotes } from '../../hooks/useQuickNotes';
import { useLocalCalendarMonth } from '../../hooks/vault/useLocalCalendarMonth';
import type { QuickNote } from '../../shared/types/quickNote';
import type { CalendarMarker, CalendarMarkerType, CalendarMonth } from '../../shared/types/calendar';

interface QuickNotesProps {
  date: string;
  composerSignal?: number;
}

interface QuickNoteItemProps {
  note: QuickNote;
  canUpdate: boolean;
  canDelete: boolean;
  disabledReason?: string;
  detailLoading: boolean;
  deleting: boolean;
  onEdit: (note: QuickNote) => void;
  onDelete: (note: QuickNote) => void;
}

interface QuickNoteGroup {
  key: 'morning' | 'afternoon' | 'evening';
  label: string;
  notes: QuickNote[];
}

interface QuickNotesCalendarPickerProps {
  selectedDate: string;
  displayMonth: dayjs.Dayjs;
  monthData?: CalendarMonth;
  loading: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onMonthChange: (offset: number) => void;
  onSelectDate: (date: string) => void;
  onToday: () => void;
}

type NoteActionScope = 'card' | 'modal';

const NOTE_GROUPS: Array<{ key: QuickNoteGroup['key']; label: string }> = [
  { key: 'morning', label: '上午' },
  { key: 'afternoon', label: '下午' },
  { key: 'evening', label: '晚上' },
];

const WEEK_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

const MARKER_LEGEND: Array<{ type: CalendarMarkerType; label: string }> = [
  { type: 'schedule', label: '日程' },
  { type: 'review', label: '复盘' },
];

function formatNoteTime(note: QuickNote): string {
  return dayjs(note.createdAt).format('HH:mm');
}

function formatDateTitle(date: string): string {
  const title = dayjs(date).format('YYYY年M月D日');
  return date === dayjs().format('YYYY-MM-DD') ? `${title} · 今天` : title;
}

function formatShortDateLabel(date: string): string {
  return date === dayjs().format('YYYY-MM-DD') ? '今天' : dayjs(date).format('M月D日');
}

function getMarkerColor(type: CalendarMarkerType): string {
  return type === 'schedule' ? '#22c55e' : '#7c3aed';
}

function getGroupKey(note: QuickNote): QuickNoteGroup['key'] {
  const hour = dayjs(note.createdAt).hour();
  if (hour < 12) return 'morning';
  if (hour < 18) return 'afternoon';
  return 'evening';
}

function buildGroups(notes: QuickNote[]): QuickNoteGroup[] {
  return NOTE_GROUPS.map((group) => ({
    ...group,
    notes: notes.filter((note) => getGroupKey(note) === group.key),
  })).filter((group) => group.notes.length > 0);
}

function buildCalendarCells(monthDate: dayjs.Dayjs) {
  const monthStart = monthDate.startOf('month');
  const leadingDays = (monthStart.day() + 6) % 7;
  const cellCount = Math.ceil((leadingDays + monthDate.daysInMonth()) / 7) * 7;
  const firstCell = monthStart.subtract(leadingDays, 'day');

  return Array.from({ length: cellCount }, (_, index) => {
    const cellDate = firstCell.add(index, 'day');
    return {
      key: cellDate.format('YYYY-MM-DD'),
      date: cellDate,
      isCurrentMonth: cellDate.month() === monthDate.month(),
    };
  });
}

function QuickNoteItem({
  note,
  canUpdate,
  canDelete,
  disabledReason,
  detailLoading,
  deleting,
  onEdit,
  onDelete,
}: QuickNoteItemProps) {
  const editDisabled = !canUpdate || detailLoading || deleting;
  const deleteDisabled = !canDelete || deleting || detailLoading;

  return (
    <article className="quick-note-item">
      <div className="quick-note-main">
        <div className="quick-note-meta">
          <span className="quick-note-dot" />
          <time className="quick-note-time" dateTime={note.createdAt}>
            {formatNoteTime(note)}
          </time>
        </div>
        <p className="quick-note-line">{note.content}</p>
      </div>
      <div className="quick-note-actions" aria-label="快速记录操作">
        <Tooltip title={editDisabled && !canUpdate ? disabledReason : ''}>
          <span>
            <Button
              type="text"
              size="small"
              icon={detailLoading ? <LoadingOutlined /> : <EditOutlined />}
              disabled={editDisabled}
              aria-label="编辑记录"
              onClick={() => onEdit(note)}
            />
          </span>
        </Tooltip>
        <Tooltip title={deleteDisabled && !canDelete ? disabledReason : ''}>
          <span>
            <Button
              type="text"
              size="small"
              danger
              icon={<DeleteOutlined />}
              disabled={deleteDisabled}
              aria-label="删除记录"
              onClick={() => onDelete(note)}
            />
          </span>
        </Tooltip>
      </div>
    </article>
  );
}

function QuickNotesCalendarPicker({
  selectedDate,
  displayMonth,
  monthData,
  loading,
  open,
  onOpenChange,
  onMonthChange,
  onSelectDate,
  onToday,
}: QuickNotesCalendarPickerProps) {
  const today = dayjs().format('YYYY-MM-DD');
  const displayMonthKey = displayMonth.format('YYYY-MM');
  const calendarCells = useMemo(() => buildCalendarCells(displayMonth), [displayMonthKey, displayMonth]);
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

  const picker = (
    <div className="quick-notes-calendar-picker">
      <div className="quick-notes-calendar-header">
        <strong>{displayMonth.format('YYYY年M月')}</strong>
        <div>
          <button type="button" aria-label="上个月" onClick={() => onMonthChange(-1)}>
            <LeftOutlined />
          </button>
          <button type="button" aria-label="下个月" onClick={() => onMonthChange(1)}>
            <RightOutlined />
          </button>
          <button type="button" className="quick-notes-calendar-today" onClick={onToday}>
            今日
          </button>
        </div>
      </div>

      <div className="quick-notes-calendar-grid">
        {WEEK_LABELS.map((label) => (
          <div key={label} className="quick-notes-calendar-weekday">
            {label}
          </div>
        ))}
        {calendarCells.map((cell) => {
          const dateStr = cell.date.format('YYYY-MM-DD');
          const markers = markerMap.get(dateStr) ?? [];
          const className = [
            'quick-notes-calendar-day',
            cell.isCurrentMonth ? '' : 'outside',
            dateStr === today ? 'today' : '',
            dateStr === selectedDate ? 'selected' : '',
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
              <span className="quick-notes-calendar-day-number">{cell.date.date()}</span>
              <span className="quick-notes-calendar-markers" aria-hidden="true">
                {markers.slice(0, 3).map((marker, index) => (
                  <span
                    key={`${marker.type}-${index}`}
                    className="quick-notes-calendar-marker"
                    style={{ backgroundColor: marker.color }}
                  />
                ))}
              </span>
            </button>
          );
        })}
      </div>

      <div className="quick-notes-calendar-legend" aria-label="月历标记说明">
        {MARKER_LEGEND.map((item) => (
          <span key={item.type}>
            <span style={{ backgroundColor: getMarkerColor(item.type) }} />
            {item.label}
          </span>
        ))}
      </div>

      {loading && (
        <div className="quick-notes-calendar-loading" role="status">
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
      placement="bottomLeft"
      open={open}
      onOpenChange={onOpenChange}
      content={picker}
      overlayClassName="quick-notes-calendar-popover"
    >
      <button type="button" className="quick-notes-date-filter" aria-label="选择快速记录日期">
        <span className="quick-notes-date-filter-main">
          <CalendarOutlined />
          <span>{formatDateTitle(selectedDate)}</span>
        </span>
        <span className="quick-notes-date-filter-meta">
          切换日期
          <DownOutlined />
        </span>
      </button>
    </Popover>
  );
}

export function QuickNotes({ date, composerSignal = 0 }: QuickNotesProps) {
  const {
    notes,
    recentNotes,
    total,
    status,
    listStatus,
    error,
    permissions,
    creating,
    updatingId,
    deletingId,
    detailLoadingId,
    refetch,
    createNote,
    loadNoteDetail,
    updateNote,
    deleteNote,
  } = useQuickNotes(date);
  const [showComposer, setShowComposer] = useState(false);
  const [draft, setDraft] = useState('');
  const [allOpen, setAllOpen] = useState(false);
  const [modalDate, setModalDate] = useState(date);
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [calendarMonth, setCalendarMonth] = useState(() => dayjs(date).startOf('month'));
  const { monthData: calendarMonthData, loading: calendarLoading } =
    useLocalCalendarMonth(calendarMonth.format('YYYY-MM'));
  const [editOpen, setEditOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<QuickNote | null>(null);
  const [editContent, setEditContent] = useState('');
  const [editScope, setEditScope] = useState<NoteActionScope>('card');
  const [deleteTarget, setDeleteTarget] = useState<QuickNote | null>(null);
  const [deleteScope, setDeleteScope] = useState<NoteActionScope>('card');
  const modalQuickNotes = useQuickNotes(modalDate);
  const modalNotes = modalDate === date ? notes : modalQuickNotes.notes;
  const modalTotal = modalDate === date ? total : modalQuickNotes.total;
  const modalStatus = modalDate === date ? status : modalQuickNotes.status;
  const modalListStatus = modalDate === date ? listStatus : modalQuickNotes.listStatus;
  const modalError = modalDate === date ? error : modalQuickNotes.error;
  const modalPermissions = modalDate === date ? permissions : modalQuickNotes.permissions;
  const modalDetailLoadingId = modalDate === date ? detailLoadingId : modalQuickNotes.detailLoadingId;
  const modalDeletingId = modalDate === date ? deletingId : modalQuickNotes.deletingId;
  const modalGroups = useMemo(() => buildGroups(modalNotes), [modalNotes]);
  const isInitialLoading = status === 'loading' && notes.length === 0;
  const modalIsInitialLoading = modalStatus === 'loading' && modalNotes.length === 0;
  const noCreateReason = permissions.reason ?? '暂无新增快速记录权限';
  const noMutationReason = permissions.reason ?? '暂无操作权限';
  const modalMutationReason = modalPermissions.reason ?? '暂无操作权限';

  useEffect(() => {
    if (composerSignal > 0) {
      setShowComposer(true);
    }
  }, [composerSignal]);

  useEffect(() => {
    setDraft('');
    setShowComposer(false);
    setAllOpen(false);
    setModalDate(date);
    setCalendarOpen(false);
    setCalendarMonth(dayjs(date).startOf('month'));
    setEditOpen(false);
    setEditTarget(null);
    setEditContent('');
    setDeleteTarget(null);
  }, [date]);

  const handleOpenComposer = useCallback(() => {
    if (!permissions.canCreate) {
      return;
    }
    setShowComposer(true);
  }, [permissions.canCreate]);

  const handleOpenAll = useCallback(() => {
    setModalDate(date);
    setCalendarMonth(dayjs(date).startOf('month'));
    setAllOpen(true);
  }, [date]);

  const handleSelectModalDate = useCallback((nextDate: string) => {
    setModalDate(nextDate);
    setCalendarMonth(dayjs(nextDate).startOf('month'));
    setCalendarOpen(false);
  }, []);

  const handleSelectTodayInModal = useCallback(() => {
    const today = dayjs().format('YYYY-MM-DD');
    setModalDate(today);
    setCalendarMonth(dayjs(today).startOf('month'));
    setCalendarOpen(false);
  }, []);

  const handleCreate = useCallback(async () => {
    const saved = await createNote(draft);
    if (saved) {
      setDraft('');
      setShowComposer(false);
    }
  }, [createNote, draft]);

  const handleOpenCardEdit = useCallback(
    async (note: QuickNote) => {
      if (!permissions.canUpdate) {
        return;
      }
      const detail = await loadNoteDetail(note.id);
      if (!detail) {
        return;
      }
      setEditScope('card');
      setEditTarget(detail);
      setEditContent(detail.content);
      setEditOpen(true);
    },
    [loadNoteDetail, permissions.canUpdate],
  );

  const handleOpenModalEdit = useCallback(
    async (note: QuickNote) => {
      if (!modalPermissions.canUpdate) {
        return;
      }
      const detail =
        modalDate === date
          ? await loadNoteDetail(note.id)
          : await modalQuickNotes.loadNoteDetail(note.id);
      if (!detail) {
        return;
      }
      setEditScope('modal');
      setEditTarget(detail);
      setEditContent(detail.content);
      setEditOpen(true);
    },
    [date, loadNoteDetail, modalDate, modalPermissions.canUpdate, modalQuickNotes],
  );

  const handleOpenCardDelete = useCallback((note: QuickNote) => {
    setDeleteScope('card');
    setDeleteTarget(note);
  }, []);

  const handleOpenModalDelete = useCallback((note: QuickNote) => {
    setDeleteScope('modal');
    setDeleteTarget(note);
  }, []);

  const handleUpdate = useCallback(async () => {
    if (!editTarget) {
      return;
    }
    const save =
      editScope === 'modal' && modalDate !== date ? modalQuickNotes.updateNote : updateNote;
    const saved = await save(editTarget.id, editContent);
    if (saved) {
      setEditOpen(false);
      setEditTarget(null);
      setEditContent('');
    }
  }, [date, editContent, editScope, editTarget, modalDate, modalQuickNotes, updateNote]);

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) {
      return;
    }
    const remove =
      deleteScope === 'modal' && modalDate !== date ? modalQuickNotes.deleteNote : deleteNote;
    const deleted = await remove(deleteTarget.id);
    if (deleted) {
      setDeleteTarget(null);
    }
  }, [date, deleteNote, deleteScope, deleteTarget, modalDate, modalQuickNotes]);

  const renderListBody = () => {
    if (isInitialLoading) {
      return (
        <div className="quick-notes-loading" role="status">
          <Spin size="small" />
          <span>正在加载快速记录...</span>
        </div>
      );
    }

    if (!permissions.canView) {
      return (
        <div className="quick-notes-empty is-permission">
          <strong>暂无查看权限</strong>
          <p>{permissions.reason ?? '当前账号不可查看该日期的快速记录。'}</p>
        </div>
      );
    }

    if (status === 'error') {
      return (
        <Alert
          type="error"
          showIcon
          className="quick-notes-alert"
          title="快速记录加载失败"
          description={error ?? '请检查网络或稍后重试。'}
          action={
            <Button size="small" aria-label="重试" onClick={() => void refetch()}>
              重试
            </Button>
          }
        />
      );
    }

    if (recentNotes.length === 0) {
      return (
        <div className="quick-notes-empty">
          <span className="quick-notes-empty-icon">
            <EditOutlined />
          </span>
          <strong>还没有快速记录</strong>
          <p>把突然想到的灵感、提醒或会议结论先放在这里。</p>
        </div>
      );
    }

    return (
      <>
        <div className="quick-notes-list">
          {recentNotes.map((note) => (
            <QuickNoteItem
              key={note.id}
              note={note}
              canUpdate={permissions.canUpdate}
              canDelete={permissions.canDelete}
              disabledReason={noMutationReason}
              detailLoading={detailLoadingId === note.id}
              deleting={deletingId === note.id}
              onEdit={handleOpenCardEdit}
              onDelete={handleOpenCardDelete}
            />
          ))}
        </div>
        {status === 'loading' && (
          <div className="quick-notes-refreshing">
            <LoadingOutlined />
            <span>正在刷新...</span>
          </div>
        )}
      </>
    );
  };

  const renderAllModalBody = () => {
    if (modalIsInitialLoading) {
      return (
        <div className="quick-notes-modal-loading" role="status">
          <Spin />
          <span>正在加载 {formatDateTitle(modalDate)} 的记录...</span>
        </div>
      );
    }

    if (!modalPermissions.canView) {
      return (
        <div className="quick-notes-modal-empty">
          {modalPermissions.reason ?? '当前账号不可查看该日期的快速记录。'}
        </div>
      );
    }

    if (modalStatus === 'error') {
      return (
        <Alert
          type="error"
          showIcon
          className="quick-notes-alert"
          title="快速记录加载失败"
          description={modalError ?? '请检查网络或稍后重试。'}
          action={
            <Button
              size="small"
              aria-label="重试"
              onClick={() => void (modalDate === date ? refetch() : modalQuickNotes.refetch())}
            >
              重试
            </Button>
          }
        />
      );
    }

    if (modalGroups.length === 0) {
      return <div className="quick-notes-modal-empty">当前日期还没有快速记录。</div>;
    }

    return (
      <div className="quick-notes-group-list">
        {modalGroups.map((group) => (
          <section className="quick-notes-group" key={group.key}>
            <h4>
              {group.label}
              <span>{group.notes.length}条</span>
            </h4>
            {group.notes.map((note) => (
              <QuickNoteItem
                key={note.id}
                note={note}
                canUpdate={modalPermissions.canUpdate}
                canDelete={modalPermissions.canDelete}
                disabledReason={modalMutationReason}
                detailLoading={modalDetailLoadingId === note.id}
                deleting={modalDeletingId === note.id}
                onEdit={handleOpenModalEdit}
                onDelete={handleOpenModalDelete}
              />
            ))}
          </section>
        ))}
      </div>
    );
  };

  return (
    <div className="quick-notes-card">
      <div className="quick-notes-header">
        <h3 className="quick-notes-title">快速记录</h3>
        <Button
          type="link"
          size="small"
          className="quick-notes-view-all"
          disabled={!permissions.canView}
          onClick={handleOpenAll}
        >
          查看全部
        </Button>
      </div>

      {listStatus === 'readonly' && (
        <div className="quick-notes-permission">当前日期只读，可查看但不可修改记录。</div>
      )}

      <div className={`quick-notes-add${showComposer ? ' is-open' : ' is-closed'}`}>
        {showComposer ? (
          <>
            <Input.TextArea
              autoFocus
              placeholder="随手记下想法、会议结论、灵感或提醒..."
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onPressEnter={(e) => {
                if (!e.shiftKey) {
                  e.preventDefault();
                  void handleCreate();
                }
              }}
              disabled={creating || !permissions.canCreate}
              autoSize={{ minRows: 5, maxRows: 10 }}
              className="quick-notes-input"
            />
            <div className="quick-notes-add-actions">
              <span className="quick-notes-save-tip">
                <CalendarOutlined />
                自动保存到 {formatDateTitle(dayjs().format('YYYY-MM-DD'))}
              </span>
              <div>
                <Button
                  size="small"
                  disabled={creating}
                  onClick={() => {
                    setShowComposer(false);
                    setDraft('');
                  }}
                >
                  取消
                </Button>
                <Button
                  type="primary"
                  size="small"
                  icon={<ThunderboltOutlined />}
                  loading={creating}
                  disabled={!draft.trim() || !permissions.canCreate}
                  onClick={() => void handleCreate()}
                >
                  快速新增
                </Button>
              </div>
            </div>
          </>
        ) : (
          <div className="quick-notes-placeholder">
            <Tooltip title={!permissions.canCreate ? noCreateReason : ''}>
              <span>
                <Button
                  className="today-quick-note-button"
                  icon={<EditOutlined />}
                  disabled={!permissions.canCreate}
                  onClick={handleOpenComposer}
                >
                  快速记录
                </Button>
              </span>
            </Tooltip>
          </div>
        )}
      </div>

      {renderListBody()}

      <div className="quick-notes-footer">
        <span>已自动保存到今天 · {dayjs().format('M月D日')}</span>
        {total > recentNotes.length && (
          <Button type="link" size="small" onClick={handleOpenAll}>
            共 {total} 条
          </Button>
        )}
      </div>

      <Modal
        title={
          <div className="quick-notes-modal-title">
            <span>全部快速记录</span>
            <small>按时间排序，可切换日期查看当天记录</small>
          </div>
        }
        open={allOpen}
        onCancel={() => setAllOpen(false)}
        footer={[
          <span className="quick-notes-modal-count" key="count">
            共 {modalTotal} 条记录
          </span>,
          <Button key="close" onClick={() => setAllOpen(false)}>
            关闭
          </Button>,
        ]}
        width={700}
        centered
        zIndex={1100}
        className="quick-notes-all-modal"
      >
        <QuickNotesCalendarPicker
          selectedDate={modalDate}
          displayMonth={calendarMonth}
          monthData={calendarMonthData}
          loading={calendarLoading}
          open={calendarOpen}
          onOpenChange={setCalendarOpen}
          onMonthChange={(offset) => setCalendarMonth((value) => value.add(offset, 'month'))}
          onSelectDate={handleSelectModalDate}
          onToday={handleSelectTodayInModal}
        />

        {modalListStatus === 'readonly' && (
          <div className="quick-notes-permission">当前日期只读，可查看但不可修改记录。</div>
        )}

        {renderAllModalBody()}
      </Modal>

      <Modal
        title="编辑快速记录"
        open={editOpen}
        okText="保存"
        cancelText="取消"
        confirmLoading={Boolean(
          editTarget &&
            (editScope === 'modal' && modalDate !== date
              ? modalQuickNotes.updatingId === editTarget.id
              : updatingId === editTarget.id),
        )}
        okButtonProps={{
          disabled: !editContent.trim() || editContent.trim() === editTarget?.content,
        }}
        onOk={() => void handleUpdate()}
        onCancel={() => {
          setEditOpen(false);
          setEditTarget(null);
          setEditContent('');
        }}
        centered
        zIndex={1250}
        className="quick-notes-edit-modal"
      >
        <Input.TextArea
          autoFocus
          value={editContent}
          onChange={(e) => setEditContent(e.target.value)}
          autoSize={{ minRows: 5, maxRows: 8 }}
          maxLength={800}
          showCount
        />
      </Modal>

      <Modal
        open={Boolean(deleteTarget)}
        title={null}
        footer={null}
        centered
        width={390}
        zIndex={1260}
        onCancel={() => setDeleteTarget(null)}
        className="quick-notes-delete-modal"
      >
        {deleteTarget && (
          <div className="quick-notes-delete-content">
            <ExclamationCircleFilled className="quick-notes-delete-icon" />
            <h3>删除这条记录？</h3>
            <p>删除后将无法恢复，确认继续吗？</p>
            <div className="quick-notes-delete-preview">
              <strong>{formatShortDateLabel(deleteTarget.date)} · {formatNoteTime(deleteTarget)}</strong>
              <span>{deleteTarget.content}</span>
            </div>
            <div className="quick-notes-delete-actions">
              <Button onClick={() => setDeleteTarget(null)}>取消</Button>
              <Button
                type="primary"
                danger
                loading={deleteScope === 'modal' && modalDate !== date
                  ? modalQuickNotes.deletingId === deleteTarget.id
                  : deletingId === deleteTarget.id}
                onClick={() => void handleDelete()}
              >
                确认删除
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
