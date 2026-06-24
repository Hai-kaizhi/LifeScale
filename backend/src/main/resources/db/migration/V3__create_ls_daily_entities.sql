-- ============================================================================
-- Daily 当天实体镜像表（docs/09 §6.2.1，P4 云端当天实体同步）
-- ============================================================================
-- 架构模型：Model A 重生版 —— 结构化生活数据 SQL-first + 沉淀分层
--   当天未沉淀实体（settled=false）镜像到云端，供跨设备 last-write-wins 同步；
--   沉淀（P2）后转走 vault 文件同步通道（Notes/Daily/<date>.md），实体不再变。
--
-- ⚠️ 表名澄清：本迁移新建的 ls_schedule / ls_quick_note / ls_review_answer /
--   ls_daily_focus 是 **Model A 重生版**（复用 vault 同步通道 + CAS，LWW 实体同步），
--   与 V1 文件头注释记录的「已废弃删除的旧 Model B per-entity REST 表」无关。
--   旧 Model B 表已随其代码整体删除，新部署从未创建过它们，本迁移在干净库上建表无冲突。
--
-- 约定（与 V1/V2 一致）：
--   - 表前缀 ls_
--   - 严格不使用外键（逻辑关联，应用层维护）
--   - 时间字段统一 TIMESTAMPTZ，默认 now()
--   - 软删除用 status 字段（active / deleted），不做物理删除
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. 日程镜像（任务 + 时间记录）；同步单位 = (user_id, entity_id) + updated_at 游标
-- ----------------------------------------------------------------------------
CREATE TABLE ls_schedule (
  id            BIGSERIAL     PRIMARY KEY,
  user_id       BIGINT        NOT NULL,                       -- 归属用户（逻辑外键）
  entity_id     VARCHAR(64)   NOT NULL,                       -- 客户端生成的稳定 UUID（实体身份）
  device_id     VARCHAR(64)   NULL,                           -- 最近修改设备
  date          DATE          NOT NULL,                       -- 'YYYY-MM-DD'
  start_time    VARCHAR(5)    NOT NULL,                       -- 'HH:MM'
  end_time      VARCHAR(5)    NOT NULL,                       -- 'HH:MM'
  title         VARCHAR(255)  NOT NULL,
  category      VARCHAR(16)   NOT NULL,                       -- '工作' | '生活'
  type          VARCHAR(16)   NOT NULL DEFAULT 'task',        -- 'task' | 'note'
  completed     BOOLEAN       NOT NULL DEFAULT FALSE,
  focus         BOOLEAN       NOT NULL DEFAULT FALSE,         -- 是否今日重点
  sort_order    INT           NOT NULL DEFAULT 0,
  settled       BOOLEAN       NOT NULL DEFAULT FALSE,         -- 当天未沉淀=false；沉淀后不再同步
  status        VARCHAR(20)   NOT NULL DEFAULT 'active',      -- active / deleted(墓碑)
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),         -- LWW 比较依据 + changes 游标
  UNIQUE (user_id, entity_id)
);

CREATE INDEX idx_schedule_changes ON ls_schedule (user_id, updated_at);
CREATE INDEX idx_schedule_user_date ON ls_schedule (user_id, date);

COMMENT ON TABLE  ls_schedule              IS '日程镜像（当天未沉淀实体跨设备 LWW 同步）；沉淀后转 vault 文件同步';
COMMENT ON COLUMN ls_schedule.user_id      IS '归属用户 ID（逻辑外键）';
COMMENT ON COLUMN ls_schedule.entity_id    IS '客户端生成的稳定实体 UUID（LWW 身份键）';
COMMENT ON COLUMN ls_schedule.device_id    IS '最近修改设备 ID';
COMMENT ON COLUMN ls_schedule.date         IS '日期 YYYY-MM-DD';
COMMENT ON COLUMN ls_schedule.start_time   IS '开始时间 HH:MM';
COMMENT ON COLUMN ls_schedule.end_time     IS '结束时间 HH:MM';
COMMENT ON COLUMN ls_schedule.title        IS '标题';
COMMENT ON COLUMN ls_schedule.category     IS '分类：工作 / 生活';
COMMENT ON COLUMN ls_schedule.type         IS '类型：task 任务 / note 时间记录';
COMMENT ON COLUMN ls_schedule.completed    IS '是否完成（任务）';
COMMENT ON COLUMN ls_schedule.focus        IS '是否今日重点';
COMMENT ON COLUMN ls_schedule.sort_order   IS '今日清单排序值';
COMMENT ON COLUMN ls_schedule.settled      IS '是否已沉淀：false 当天未沉淀（参与同步）/ true 已沉淀（不再同步）';
COMMENT ON COLUMN ls_schedule.status       IS '状态：active 活跃 / deleted 墓碑（删除传播）';
COMMENT ON COLUMN ls_schedule.created_at   IS '创建时间';
COMMENT ON COLUMN ls_schedule.updated_at   IS '最后更新时间（LWW 比较依据 + changes 游标）';


-- ----------------------------------------------------------------------------
-- 2. 快速记录镜像
-- ----------------------------------------------------------------------------
CREATE TABLE ls_quick_note (
  id            BIGSERIAL     PRIMARY KEY,
  user_id       BIGINT        NOT NULL,
  entity_id     VARCHAR(64)   NOT NULL,
  device_id     VARCHAR(64)   NULL,
  date          DATE          NOT NULL,
  content       TEXT          NOT NULL,
  settled       BOOLEAN       NOT NULL DEFAULT FALSE,
  status        VARCHAR(20)   NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity_id)
);

CREATE INDEX idx_quick_note_changes ON ls_quick_note (user_id, updated_at);
CREATE INDEX idx_quick_note_user_date ON ls_quick_note (user_id, date);

COMMENT ON TABLE  ls_quick_note              IS '快速记录镜像（当天未沉淀实体跨设备 LWW 同步）';
COMMENT ON COLUMN ls_quick_note.user_id      IS '归属用户 ID（逻辑外键）';
COMMENT ON COLUMN ls_quick_note.entity_id    IS '客户端生成的稳定实体 UUID（LWW 身份键）';
COMMENT ON COLUMN ls_quick_note.device_id    IS '最近修改设备 ID';
COMMENT ON COLUMN ls_quick_note.date         IS '日期 YYYY-MM-DD';
COMMENT ON COLUMN ls_quick_note.content      IS '内容';
COMMENT ON COLUMN ls_quick_note.settled      IS '是否已沉淀：false 当天未沉淀 / true 已沉淀';
COMMENT ON COLUMN ls_quick_note.status       IS '状态：active / deleted(墓碑)';
COMMENT ON COLUMN ls_quick_note.created_at   IS '创建时间';
COMMENT ON COLUMN ls_quick_note.updated_at   IS '最后更新时间（LWW + 游标）';


-- ----------------------------------------------------------------------------
-- 3. 复盘答案镜像（每题一条）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_review_answer (
  id            BIGSERIAL     PRIMARY KEY,
  user_id       BIGINT        NOT NULL,
  entity_id     VARCHAR(64)   NOT NULL,                       -- = question_id（一题一条）
  device_id     VARCHAR(64)   NULL,
  date          DATE          NOT NULL,
  question_id   VARCHAR(64)   NOT NULL,                       -- 关联复盘方案题目 ID
  title         VARCHAR(255)  NOT NULL,                       -- 快照（防 scheme 改动丢语义）
  content       TEXT          NOT NULL DEFAULT '',
  settled       BOOLEAN       NOT NULL DEFAULT FALSE,
  status        VARCHAR(20)   NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity_id)
);

CREATE INDEX idx_review_answer_changes ON ls_review_answer (user_id, updated_at);
CREATE INDEX idx_review_answer_user_date ON ls_review_answer (user_id, date);

COMMENT ON TABLE  ls_review_answer              IS '复盘答案镜像（当天未沉淀实体跨设备 LWW 同步）';
COMMENT ON COLUMN ls_review_answer.user_id      IS '归属用户 ID（逻辑外键）';
COMMENT ON COLUMN ls_review_answer.entity_id    IS '客户端生成的稳定实体 UUID（= question_id，LWW 身份键）';
COMMENT ON COLUMN ls_review_answer.device_id    IS '最近修改设备 ID';
COMMENT ON COLUMN ls_review_answer.date         IS '日期 YYYY-MM-DD';
COMMENT ON COLUMN ls_review_answer.question_id  IS '复盘方案题目 ID';
COMMENT ON COLUMN ls_review_answer.title        IS '题目标题快照';
COMMENT ON COLUMN ls_review_answer.content      IS '答案内容';
COMMENT ON COLUMN ls_review_answer.settled      IS '是否已沉淀';
COMMENT ON COLUMN ls_review_answer.status       IS '状态：active / deleted(墓碑)';
COMMENT ON COLUMN ls_review_answer.created_at   IS '创建时间';
COMMENT ON COLUMN ls_review_answer.updated_at   IS '最后更新时间（LWW + 游标）';


-- ----------------------------------------------------------------------------
-- 4. 今日重点镜像（自由文本，单条/日；以 date 为业务身份）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_daily_focus (
  id            BIGSERIAL     PRIMARY KEY,
  user_id       BIGINT        NOT NULL,
  date          DATE          NOT NULL,
  content       TEXT          NULL,                           -- 自由文本，可空
  settled       BOOLEAN       NOT NULL DEFAULT FALSE,
  status        VARCHAR(20)   NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

CREATE INDEX idx_daily_focus_changes ON ls_daily_focus (user_id, updated_at);

COMMENT ON TABLE  ls_daily_focus              IS '今日重点镜像（自由文本，当天未沉淀实体跨设备 LWW 同步）';
COMMENT ON COLUMN ls_daily_focus.user_id      IS '归属用户 ID（逻辑外键）';
COMMENT ON COLUMN ls_daily_focus.date         IS '日期 YYYY-MM-DD（业务身份键）';
COMMENT ON COLUMN ls_daily_focus.content      IS '自由文本重点，可空';
COMMENT ON COLUMN ls_daily_focus.settled      IS '是否已沉淀';
COMMENT ON COLUMN ls_daily_focus.status       IS '状态：active / deleted(墓碑)';
COMMENT ON COLUMN ls_daily_focus.created_at   IS '创建时间';
COMMENT ON COLUMN ls_daily_focus.updated_at   IS '最后更新时间（LWW + 游标）';
