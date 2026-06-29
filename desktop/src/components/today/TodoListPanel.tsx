import { Checkbox, Dropdown, type MenuProps } from 'antd';
import {
  CheckOutlined,
  DeleteOutlined,
  EditOutlined,
  StarFilled,
  StarOutlined,
  SwapOutlined,
} from '@ant-design/icons';
import { useState } from 'react';
import type { CSSProperties } from 'react';
import {
  DndContext,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  SortableContext,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import type { Schedule, ScheduleType } from '../../shared/types/schedule';

interface TodoListPanelProps {
  schedules: Schedule[];
  onToggle: (schedule: Schedule) => void;
  onDelete: (schedule: Schedule) => void;
  onOpenCreate: () => void;
  /** 打开编辑弹窗 */
  onEdit?: (schedule: Schedule) => void;
  /** 转换日程类型：task ↔ note */
  onConvert?: (schedule: Schedule, type: ScheduleType) => void;
  /** 标记/取消今日重点 */
  onToggleFocus?: (schedule: Schedule) => void;
  /** 拖拽排序后回调（传入重排后的完整列表） */
  onReorder?: (schedules: Schedule[]) => void;
}

function isNote(schedule: Schedule) {
  return schedule.type === 'note';
}

export function TodoListPanel({ schedules, onToggle, onDelete, onOpenCreate, onEdit, onConvert, onToggleFocus, onReorder }: TodoListPanelProps) {
  // 按 sortOrder 排序（不再因完成状态而变动位置），缺失 sortOrder 时回退到 startTime
  const [ordered, setOrdered] = useState<Schedule[]>(() => [...schedules].sort(sortByOrder));
  // 外部 schedules 变化时同步（如新建、删除、切换日期）
  const [lastSchedulesRef, setLastSchedulesRef] = useState(schedules);
  if (schedules !== lastSchedulesRef) {
    setLastSchedulesRef(schedules);
    setOrdered([...schedules].sort(sortByOrder));
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
  );

  function sortByOrder(a: Schedule, b: Schedule) {
    const sa = a.sortOrder ?? 0;
    const sb = b.sortOrder ?? 0;
    if (sa !== sb) return sa - sb;
    return (a.startTime ?? '').localeCompare(b.startTime ?? '');
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const oldIndex = ordered.findIndex((s) => s.id === active.id);
    const newIndex = ordered.findIndex((s) => s.id === over.id);
    if (oldIndex < 0 || newIndex < 0) return;
    // 重排数组
    const next = [...ordered];
    const [moved] = next.splice(oldIndex, 1);
    next.splice(newIndex, 0, moved);
    // 分配新的 sortOrder（0,1,2...）
    const withOrder = next.map((s, i) => ({ ...s, sortOrder: i }));
    setOrdered(withOrder);
    onReorder?.(withOrder);
  }

  function buildMenu(schedule: Schedule): MenuProps {
    const note = isNote(schedule);
    const items: MenuProps['items'] = [];
    // 记录类型仅作备忘，无需完成状态，不显示「标记为已完成」选项
    if (!note) {
      items.push({
        key: 'toggle',
        label: schedule.completed ? '标记为未完成' : '标记为已完成',
        icon: <CheckOutlined />,
        onClick: () => onToggle(schedule),
      });
    }
    items.push(
      {
        key: 'convert',
        label: note ? '转为任务' : '转为记录',
        icon: <SwapOutlined />,
        onClick: () => onConvert?.(schedule, note ? 'task' : 'note'),
      },
    );
    // 标记/取消今日重点
    items.push({
      key: 'focus',
      label: schedule.focus ? '取消今日重点' : '设为今日重点',
      icon: schedule.focus ? <StarFilled style={{ color: '#ef4444' }} /> : <StarOutlined />,
      onClick: () => onToggleFocus?.(schedule),
    });
    items.push(
      { type: 'divider' as const },
      {
        key: 'edit',
        label: '编辑',
        icon: <EditOutlined />,
        onClick: () => onEdit?.(schedule),
      },
      {
        key: 'delete',
        label: '删除',
        icon: <DeleteOutlined />,
        danger: true,
        onClick: () => onDelete(schedule),
      },
    );
    return { items };
  }

  return (
    <aside className="todo-list-panel" aria-label="今日清单">
      <div className="todo-list-heading">
        <div className="todo-list-title">
          <CheckOutlined />
          <span>今日清单</span>
        </div>
        <span className="todo-list-count">{schedules.length}</span>
      </div>

      <div className="todo-list-body">
        {ordered.length === 0 ? (
          <div className="todo-list-empty">
            <span>暂无清单项</span>
            <button type="button" className="todo-list-empty-btn" onClick={onOpenCreate}>
              添加一项
            </button>
          </div>
        ) : (
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={ordered.map((s) => s.id)}
              strategy={verticalListSortingStrategy}
            >
              {ordered.map((schedule) => (
                <SortableTodoItem
                  key={schedule.id}
                  schedule={schedule}
                  onToggle={onToggle}
                  onDelete={onDelete}
                  onEdit={onEdit}
                  buildMenu={buildMenu}
                />
              ))}
            </SortableContext>
          </DndContext>
        )}
      </div>
    </aside>
  );
}

/* ---------- 可拖拽的清单项 ---------- */

interface SortableTodoItemProps {
  schedule: Schedule;
  onToggle: (schedule: Schedule) => void;
  onDelete: (schedule: Schedule) => void;
  onEdit?: (schedule: Schedule) => void;
  buildMenu: (schedule: Schedule) => MenuProps;
}

function SortableTodoItem({ schedule, onToggle, onDelete, onEdit, buildMenu }: SortableTodoItemProps) {
  const note = isNote(schedule);
  const completed = !!schedule.completed;
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: schedule.id,
  });
  const itemStyle = {
    '--schedule-color': schedule.categoryColor,
    transform: CSS.Transform.toString(transform),
    transition,
  } as CSSProperties;

  return (
    <Dropdown menu={buildMenu(schedule)} trigger={['contextMenu']}>
      <div
        ref={setNodeRef}
        className={`todo-item${completed && !note ? ' is-completed' : ''}${
          note ? ' is-note' : ' is-task'
        }${schedule.focus ? ' is-focus' : ''}${isDragging ? ' is-dragging' : ''}`}
        style={itemStyle}
        onDoubleClick={() => onEdit?.(schedule)}
        title="双击编辑日程"
      >
        <div className="todo-item-drag-handle" {...attributes} {...listeners} aria-label="拖拽排序">
          <span className="todo-item-grip" aria-hidden="true" />
        </div>
        <div
          className="todo-item-indicator"
          onDoubleClick={(e) => e.stopPropagation()}
        >
          {note ? (
            <span className="todo-item-dot" aria-hidden="true" />
          ) : (
            <Checkbox
              checked={completed}
              onChange={() => onToggle(schedule)}
              aria-label={`标记 ${schedule.title} 为${completed ? '未完成' : '已完成'}`}
            />
          )}
        </div>
        <div className="todo-item-main">
          <strong className="todo-item-title">
            {schedule.focus && (
              <StarFilled className="todo-item-focus-icon" style={{ color: '#ef4444' }} />
            )}
            {schedule.title}
          </strong>
          <span className="todo-item-meta">
            {schedule.startTime}-{schedule.endTime}
            <span className="todo-item-category">{schedule.category}</span>
          </span>
        </div>
        <div
          className="todo-item-actions"
          onDoubleClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            className="todo-item-edit"
            aria-label="编辑"
            title="编辑"
            onClick={(e) => {
              e.stopPropagation();
              onEdit?.(schedule);
            }}
          >
            <EditOutlined />
          </button>
          <button
            type="button"
            className="todo-item-delete"
            aria-label="删除"
            title="删除"
            onClick={(e) => {
              e.stopPropagation();
              onDelete(schedule);
            }}
          >
            <DeleteOutlined />
          </button>
        </div>
      </div>
    </Dropdown>
  );
}
