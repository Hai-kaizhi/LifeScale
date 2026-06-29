/**
 * Daily 实体同步 DTO 类型（对齐后端 vault.daily.dto，camelCase JSON key）。
 * docs/09 §9.3 当天未沉淀实体跨设备 LWW 同步。
 */

/** 日程镜像（任务 + 时间记录）。id = 客户端实体 UUID（LWW 身份键）。 */
export interface ScheduleMirrorData {
  id: string;
  date: string; // YYYY-MM-DD
  startTime: string;
  endTime: string;
  title: string;
  category: string; // '工作' | '生活'
  type: string; // 'task' | 'note'
  completed: boolean;
  focus: boolean;
  sortOrder: number;
  settled: boolean;
  deleted: boolean;
  updatedAt: string; // ISO8601，LWW 比较 + 游标
}

/** 快速记录镜像。id = 客户端实体 UUID。 */
export interface QuickNoteMirrorData {
  id: string;
  date: string;
  content: string;
  settled: boolean;
  deleted: boolean;
  updatedAt: string;
}

/** 复盘答案镜像（每题一条）。id = questionId。 */
export interface ReviewAnswerMirrorData {
  id: string;
  date: string;
  questionId: string;
  title: string;
  content: string;
  settled: boolean;
  deleted: boolean;
  updatedAt: string;
}

/** 今日重点镜像（自由文本，单条/日）。date 为业务身份。 */
export interface DailyFocusMirrorData {
  date: string;
  content: string | null;
  settled: boolean;
  deleted: boolean;
  updatedAt: string;
}

/** 推送 4 类当天未沉淀实体（批量）。 */
export interface DailyEntityPushPayload {
  schedules: ScheduleMirrorData[];
  quickNotes: QuickNoteMirrorData[];
  reviewAnswers: ReviewAnswerMirrorData[];
  dailyFocuses: DailyFocusMirrorData[];
  deviceId?: string;
}

/** /api/vault/daily-entities/changes 返回：4 类增量变更 + 游标。 */
export interface DailyEntityChangesData {
  schedules: ScheduleMirrorData[];
  quickNotes: QuickNoteMirrorData[];
  reviewAnswers: ReviewAnswerMirrorData[];
  dailyFocuses: DailyFocusMirrorData[];
  nextCursor: string;
  hasMore: boolean;
}

/** 推送结果：覆盖数 / 丢弃数（LWW 旧版本被跳过）。 */
export interface DailyEntitySyncResult {
  pushed: number;
  skipped: number;
}
