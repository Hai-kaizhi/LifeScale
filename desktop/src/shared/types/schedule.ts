export type ScheduleCategory = '生活' | '工作';
export type ScheduleType = 'task' | 'note';

/**
 * 同一时段（时间相互重叠）允许并排的最大日程数（任务与记录合计）。
 * 超过此数量时列宽过窄、卡片不可读，且同一时段也难以并行处理更多事项，因此在创建时拦截。
 */
export const MAX_OVERLAP_SCHEDULES = 3;

/**
 * 每天允许的「今日重点」数量上限，与后端 MAX_FOCUS_PER_DAY 保持一致。
 */
export const MAX_FOCUS_PER_DAY = 3;

/**
 * 拖拽排序的单项：日程 ID + 新排序值。
 */
export interface ReorderItem {
  id: string;
  sortOrder: number;
}

/**
 * 批量重排请求：日期 + 重排项列表。
 */
export interface ReorderPayload {
  date: string;
  items: ReorderItem[];
}

export interface Schedule {
  id: string;
  title: string;
  completed?: boolean;
  category: ScheduleCategory;
  categoryColor: string;
  type?: ScheduleType;
  /** 是否为今日重点 */
  focus?: boolean;
  /** 今日清单排序值（数字越小越靠前） */
  sortOrder?: number;
  startTime: string;
  endTime: string;
  date: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateSchedulePayload {
  date: string;
  title: string;
  startTime: string;
  endTime: string;
  category?: ScheduleCategory;
  type?: ScheduleType;
}

export interface UpdateSchedulePayload {
  id: string;
  title?: string;
  startTime?: string;
  endTime?: string;
  category?: ScheduleCategory;
  type?: ScheduleType;
  focus?: boolean;
}

/**
 * 转换日程类型的便捷 payload，仅更新 type 字段。
 */
export interface ConvertScheduleTypePayload {
  id: string;
  type: ScheduleType;
}

export interface ToggleSchedulePayload {
  id: string;
  completed: boolean;
}

export const SCHEDULE_CATEGORY_COLORS: Record<ScheduleCategory, string> = {
  '生活': '#22c55e',
  '工作': '#3b82f6',
};
