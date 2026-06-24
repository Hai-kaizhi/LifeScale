import { useCallback, useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import { Form, Input, message, Modal, TimePicker } from 'antd';
import dayjs from 'dayjs';
import type { Dayjs } from 'dayjs';
import type { Schedule, ScheduleCategory, ScheduleType } from '../../shared/types/schedule';
import { MAX_OVERLAP_SCHEDULES, SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';

interface ScheduleFormModalProps {
  currentDate: string;
  open: boolean;
  onCancel: () => void;
  /** 新建成功回调 */
  onCreated: (schedule: Schedule) => void;
  /** 编辑成功回调 */
  onUpdated?: (schedule: Schedule) => void;
  /** 当前日期已有的日程，用于校验同一时段并排上限 */
  existingSchedules?: Schedule[];
  /** 编辑目标；为 null/undefined 时进入新建模式 */
  editTarget?: Schedule | null;
}

interface ScheduleFormValues {
  title: string;
  startTime: Dayjs;
  endTime: Dayjs;
  category: ScheduleCategory;
  type: ScheduleType;
}

interface CategoryOption {
  value: ScheduleCategory;
  label: string;
  desc: string;
  color: string;
  icon: string;
}

interface TypeOption {
  value: ScheduleType;
  label: string;
  desc: string;
  icon: string;
}

const CATEGORY_OPTIONS: CategoryOption[] = [
  {
    value: '生活',
    label: '生活',
    desc: '日常起居、运动、休息',
    color: '#22c55e',
    icon: '🌿',
  },
  {
    value: '工作',
    label: '工作',
    desc: '任务、会议、学习',
    color: '#3b82f6',
    icon: '💼',
  },
];

const TYPE_OPTIONS: TypeOption[] = [
  {
    value: 'task',
    label: '任务',
    desc: '需要完成，可勾选打勾',
    icon: '✓',
  },
  {
    value: 'note',
    label: '记录',
    desc: '仅作备忘，不用打卡',
    icon: '•',
  },
];

function createTime(hour: number, minute: number): Dayjs {
  return dayjs().hour(hour).minute(minute).second(0).millisecond(0);
}

/** 生成本地日程稳定 ID（本地优先，不再由后端分配）。 */
function newScheduleId(): string {
  try {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
  } catch {
    /* fallthrough */
  }
  return `sch-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function parseTimeToDayjs(time: string): Dayjs {
  if (time === '24:00') {
    // 24:00 用 23:59 作为 TimePicker 可表达的上限（提交时再转回 24:00）
    return createTime(23, 59);
  }
  const [hour, minute] = time.split(':').map(Number);
  return createTime(hour, minute);
}

function isEndAfterStart(startTime?: Dayjs, endTime?: Dayjs): boolean {
  if (!startTime || !endTime) return true;
  return endTime.hour() * 60 + endTime.minute() > startTime.hour() * 60 + startTime.minute();
}

function toMinutes(time: string): number {
  if (time === '24:00') return 24 * 60;
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

/**
 * 统计与 [start, end) 区间重叠的已有日程数量。
 * 用于创建/编辑时拦截：同一时段并排超过上限会让卡片过窄不可读。
 * 编辑时需排除自身，避免把自己算进重叠数。
 */
function countOverlapping(
  existing: Schedule[],
  start: number,
  end: number,
  excludeId?: string,
): number {
  return existing.filter((item) => {
    if (excludeId && item.id === excludeId) return false;
    const s = toMinutes(item.startTime);
    const e = toMinutes(item.endTime);
    return s < end && e > start;
  }).length;
}

function isUnchanged(
  values: ScheduleFormValues,
  target: Schedule,
  endTimeStr: string,
): boolean {
  return (
    values.title.trim() === target.title &&
    values.startTime.format('HH:mm') === target.startTime &&
    endTimeStr === target.endTime &&
    values.category === target.category &&
    values.type === (target.type ?? 'task')
  );
}

export function ScheduleFormModal({
  currentDate,
  open,
  onCancel,
  onCreated,
  onUpdated,
  existingSchedules = [],
  editTarget,
}: ScheduleFormModalProps) {
  const [form] = Form.useForm<ScheduleFormValues>();
  const [submitting, setSubmitting] = useState(false);
  // 同步提交锁：ref 比 state 更可靠，连点时第二次调用能立即读到 true，彻底杜绝重复提交
  const submittingRef = useRef(false);
  const [category, setCategory] = useState<ScheduleCategory>('生活');
  const [type, setType] = useState<ScheduleType>('task');

  const isEdit = Boolean(editTarget);

  // 打开时根据模式回填表单：编辑模式预填目标日程，新建模式恢复默认值
  useEffect(() => {
    if (!open) return;
    if (editTarget) {
      const next: ScheduleFormValues = {
        title: editTarget.title,
        startTime: parseTimeToDayjs(editTarget.startTime),
        endTime: parseTimeToDayjs(editTarget.endTime),
        category: editTarget.category,
        type: editTarget.type ?? 'task',
      };
      form.setFieldsValue(next);
      setCategory(next.category);
      setType(next.type);
    } else {
      form.setFieldsValue({
        category: '生活',
        type: 'task',
        startTime: createTime(9, 0),
        endTime: createTime(10, 0),
      });
      setCategory('生活');
      setType('task');
    }
  }, [form, open, editTarget]);

  const handleSubmit = useCallback(async () => {
    // 防重入：用同步 ref 锁住，连点「确定」时第二次调用能立即读到锁，彻底杜绝重复提交
    if (submittingRef.current) return;
    submittingRef.current = true;

    let values: ScheduleFormValues;
    try {
      values = await form.validateFields();
    } catch {
      // 校验失败（含时段重叠超限）由 antd Form 在字段下方展示内联错误，不进入提交流程
      submittingRef.current = false;
      return;
    }

    setSubmitting(true);
    try {
      // 结束时间 23:59 视作 24:00 提交
      const endTimeStr =
        values.endTime.hour() === 23 && values.endTime.minute() === 59
          ? '24:00'
          : values.endTime.format('HH:mm');
      const startTimeStr = values.startTime.format('HH:mm');

      if (isEdit && editTarget) {
        // 内容未变化时直接关闭，避免无意义的本地写入
        if (isUnchanged(values, editTarget, endTimeStr)) {
          onUpdated?.(editTarget);
          return;
        }

        const updated: Schedule = {
          ...editTarget,
          title: values.title.trim(),
          category: values.category,
          categoryColor: SCHEDULE_CATEGORY_COLORS[values.category],
          type: values.type,
          startTime: startTimeStr,
          endTime: endTimeStr,
          updatedAt: new Date().toISOString(),
        };
        message.success('日程已更新');
        onUpdated?.(updated);
      } else {
        const now = new Date().toISOString();
        const created: Schedule = {
          id: newScheduleId(),
          title: values.title.trim(),
          completed: false,
          category: values.category,
          categoryColor: SCHEDULE_CATEGORY_COLORS[values.category],
          type: values.type,
          focus: false,
          startTime: startTimeStr,
          endTime: endTimeStr,
          date: currentDate,
          createdAt: now,
          updatedAt: now,
        };
        message.success('日程已创建');
        form.resetFields();
        onCreated(created);
      }
    } finally {
      setSubmitting(false);
      submittingRef.current = false;
    }
  }, [currentDate, editTarget, form, isEdit, onCreated, onUpdated]);

  // 编辑模式下重叠校验需排除自身，避免把自己的原时段算入并排上限
  const overlapExcludeId = editTarget?.id;

  return (
    <Modal
      title={isEdit ? '编辑日程' : '新建日程'}
      open={open}
      onCancel={onCancel}
      onOk={handleSubmit}
      confirmLoading={submitting}
      okText={isEdit ? '保存' : '创建日程'}
      cancelText="取消"
      centered
      destroyOnHidden
      className="schedule-create-modal"
    >
      <Form
        form={form}
        layout="vertical"
        initialValues={{
          category: '生活',
          type: 'task',
          startTime: createTime(9, 0),
          endTime: createTime(10, 0),
        }}
        className="schedule-create-form"
      >
        <Form.Item
          label="日程标题"
          name="title"
          rules={[
            { required: true, message: '请输入日程标题' },
            { whitespace: true, message: '日程标题不能为空' },
          ]}
        >
          <Input placeholder="例如：深度工作" maxLength={40} showCount />
        </Form.Item>

        <div className="schedule-create-form-grid">
          <Form.Item
            label="开始时间"
            name="startTime"
            dependencies={['endTime']}
            validateTrigger="onChange"
            rules={[
              { required: true, message: '请选择开始时间' },
              ({ getFieldValue }) => ({
                validator(_, value: Dayjs | undefined) {
                  if (isEndAfterStart(value, getFieldValue('endTime'))) {
                    return Promise.resolve();
                  }
                  return Promise.reject(new Error('开始时间必须早于结束时间'));
                },
              }),
            ]}
          >
            <TimePicker
              format="HH:mm"
              minuteStep={5}
              needConfirm={false}
              placeholder="开始时间"
            />
          </Form.Item>

          <Form.Item
            label="结束时间"
            name="endTime"
            dependencies={['startTime']}
            validateTrigger="onChange"
            rules={[
              { required: true, message: '请选择结束时间' },
              ({ getFieldValue }) => ({
                validator(_, value: Dayjs | undefined) {
                  if (!isEndAfterStart(getFieldValue('startTime'), value)) {
                    return Promise.reject(new Error('结束时间必须晚于开始时间'));
                  }
                  // 同一时段并排上限校验：当前时段与已有日程重叠数已达上限则拒绝
                  // 走到这里说明 isEndAfterStart 已通过，startTime 与 value 必定有值
                  const startVal = getFieldValue('startTime')!;
                  const endVal = value!;
                  const startMin = startVal.hour() * 60 + startVal.minute();
                  const endMin = endVal.hour() * 60 + endVal.minute();
                  const overlapping = countOverlapping(
                    existingSchedules,
                    startMin,
                    endMin,
                    overlapExcludeId,
                  );
                  if (overlapping >= MAX_OVERLAP_SCHEDULES) {
                    return Promise.reject(
                      new Error(
                        `该时段已有 ${overlapping} 个日程并排，最多支持 ${MAX_OVERLAP_SCHEDULES} 个，请调整时间`,
                      ),
                    );
                  }
                  return Promise.resolve();
                },
              }),
            ]}
          >
            <TimePicker
              format="HH:mm"
              minuteStep={5}
              needConfirm={false}
              placeholder="结束时间"
            />
          </Form.Item>
        </div>

        {/* 性质：决定日程归属的生活/工作类别，卡片左侧色条与清单标签都取自这里 */}
        <Form.Item label="性质" name="category" rules={[{ required: true, message: '请选择性质' }]}>
          <ScheduleOptionPicker<ScheduleCategory>
            options={CATEGORY_OPTIONS}
            value={category}
            onChange={setCategory}
          />
        </Form.Item>

        {/* 类型：任务可勾选完成度，记录仅作备忘不打卡 */}
        <Form.Item label="类型" name="type" rules={[{ required: true, message: '请选择类型' }]}>
          <ScheduleOptionPicker<ScheduleType>
            typeOptions
            options={TYPE_OPTIONS}
            value={type}
            onChange={setType}
          />
        </Form.Item>
      </Form>
    </Modal>
  );
}

/* ---------- 通用卡片式选择器：性质 / 类型共用，带说明文字让用户理解选项含义 ---------- */

interface PickerOptionBase {
  value: string;
  label: string;
  desc: string;
  icon: string;
  /** 可选主题色，性质选择器用它区分生活/工作；类型选择器留空统一蓝色 */
  color?: string;
}

interface PickerProps<T extends string> {
  options: PickerOptionBase[];
  value: T;
  onChange: (value: T) => void;
  /** 是否为「类型」选择器（影响配色：类型用蓝色，性质用各自颜色） */
  typeOptions?: boolean;
}

function ScheduleOptionPicker<T extends string>({
  options,
  value,
  onChange,
  typeOptions = false,
}: PickerProps<T>) {
  return (
    <div className={`schedule-option-group${typeOptions ? ' is-type' : ''}`} role="radiogroup">
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            role="radio"
            aria-checked={active}
            className={`schedule-option${active ? ' is-active' : ''}`}
            style={
              active && !typeOptions && option.color
                ? ({ '--option-color': option.color } as CSSProperties)
                : undefined
            }
            onClick={() => onChange(option.value as T)}
          >
            <span className="schedule-option-icon">{option.icon}</span>
            <span className="schedule-option-text">
              <strong className="schedule-option-label">{option.label}</strong>
              <span className="schedule-option-desc">{option.desc}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}
