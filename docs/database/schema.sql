-- ============================================================================
-- LifeScale 本地 SQLite Schema —— 单一真相源（Single Source of Truth）
-- ============================================================================
-- 用途：本文件是 LifeScale **本地 SQLite 数据库结构**的唯一规范参照。
--       桌面端 / 移动端各自的 SQLite 表结构均以此为准；修改任何表结构必须
--       先改本文件，再同步两端实现。
--
-- 架构模型：本地优先 + SQL-first 真相源 + Markdown 沉淀投影
--   - 本地 SQLite 是 Daily 实体（当天未沉淀）的唯一真相源。
--   - 无云端、无服务端、无跨设备同步：每台设备各自独立运行、独立存储。
--   - 沉淀后实体转写为本地 Markdown 文件（Vault），实体表不再变化。
--
-- Vault 文件说明（重要）：
--   以下笔记内容以本地 Markdown 文件存储，**不在 SQLite 中**：
--     - Daily/<date>.md   每日沉淀归档（当日实体沉淀后的纯净 Markdown）
--     - Notes/*.md        笔记知识库
--     - Reviews/scheme.md 复盘方案（Markdown 形式）
--   SQLite 只存"当天热数据"（结构化实体），冷归档是本地 .md 文件。
--
-- 表清单总览（本地 SQLite 共 6 张表，全部为本地业务表，无云端表）：
--   ┌─ 本地业务实体表（桌面 lifescale_db.rs / 移动 lifescale_db_service.dart）
--   │   ls_schedule         日程（任务 + 时间记录，当天未沉淀真相源）
--   │   ls_quick_note       快速记录
--   │   ls_review_answer    复盘答案（每题一条）
--   │   ls_daily_focus      今日重点（自由文本，单条/日）
--   │
--   └─ 本地独有表
--       ls_review_scheme    复盘方案题目（本地生成、本地存储）
--       ls_daily_settlement 每日沉淀记录（本地沉淀状态机）
--
-- 本地 SQLite 约定：
--   - 表前缀 ls_
--   - 主键 id TEXT（实体 UUID，客户端生成）
--   - 无 user_id（单设备单用户，无需归属）
--   - 软删除用 deleted INTEGER（0=活跃 / 1=墓碑），不做物理删除
--   - 时间字段用 TEXT，由应用层维护（created_at / updated_at）
--
-- 两端实现文件锚点（修改时务必同步）：
--   - desktop:  desktop/src-tauri/src/lifescale_db.rs
--   - mobile:   mobile/lib/core/storage/lifescale_db_service.dart
-- ============================================================================


-- ############################################################################
-- 本地 SQLite 业务表（桌面 + 移动，1:1 对齐）
-- ############################################################################

-- ----------------------------------------------------------------------------
-- 表 1：ls_schedule 日程（任务 + 时间记录，当天未沉淀真相源）
-- ----------------------------------------------------------------------------
-- id TEXT(实体UUID) 主键，无 user_id（单设备单用户），deleted INTEGER 软删除
CREATE TABLE ls_schedule (
  id            TEXT PRIMARY KEY,            -- 实体 UUID（客户端生成）
  date          TEXT NOT NULL,               -- YYYY-MM-DD
  start_time    TEXT NOT NULL,               -- HH:MM
  end_time      TEXT NOT NULL,               -- HH:MM
  title         TEXT NOT NULL,
  category      TEXT NOT NULL,               -- 工作 / 生活
  type          TEXT NOT NULL DEFAULT 'task', -- task / note
  completed     INTEGER NOT NULL DEFAULT 0,
  focus         INTEGER NOT NULL DEFAULT 0,  -- 是否今日重点
  sort_order    INTEGER NOT NULL DEFAULT 0,
  settled       INTEGER NOT NULL DEFAULT 0,  -- 0=当天未沉淀 / 1=已沉淀（已转写为 .md）
  source_device TEXT,                        -- 最近修改设备（本地记录用）
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  deleted       INTEGER NOT NULL DEFAULT 0   -- 0=活跃 / 1=墓碑
);

-- ----------------------------------------------------------------------------
-- 表 2：ls_quick_note 快速记录
-- ----------------------------------------------------------------------------
CREATE TABLE ls_quick_note (
  id            TEXT PRIMARY KEY,
  date          TEXT NOT NULL,
  content       TEXT NOT NULL,
  source_device TEXT,
  settled       INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  deleted       INTEGER NOT NULL DEFAULT 0
);

-- ----------------------------------------------------------------------------
-- 表 3：ls_review_answer 复盘答案（每题一条，id = 实体 UUID）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_review_answer (
  id           TEXT PRIMARY KEY,
  date         TEXT NOT NULL,
  question_id  TEXT NOT NULL,                -- 关联 ls_review_scheme 题目
  title        TEXT NOT NULL,                -- 快照（防 scheme 改动丢语义）
  content      TEXT NOT NULL DEFAULT '',
  settled      INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  deleted      INTEGER NOT NULL DEFAULT 0
);

-- ----------------------------------------------------------------------------
-- 表 4：ls_daily_focus 今日重点（自由文本，单条/日，以 date 为业务身份）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_daily_focus (
  id         TEXT PRIMARY KEY,
  date       TEXT NOT NULL,                  -- 业务身份键（UNIQUE per date）
  content    TEXT,
  settled    INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted    INTEGER NOT NULL DEFAULT 0
);

-- ----------------------------------------------------------------------------
-- 表 5：ls_review_scheme 复盘方案题目
--   本地生成、本地存储；方案也以 Markdown 形式（Reviews/scheme.md）留存。
-- ----------------------------------------------------------------------------
CREATE TABLE ls_review_scheme (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  questions  TEXT NOT NULL,                  -- JSON 数组：题目列表
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- ----------------------------------------------------------------------------
-- 表 6：ls_daily_settlement 每日沉淀记录
--   记录每日实体的沉淀状态机：沉淀后当天实体转写为 Daily/<date>.md。
-- ----------------------------------------------------------------------------
CREATE TABLE ls_daily_settlement (
  date            TEXT PRIMARY KEY,          -- 沉淀日期
  settled         INTEGER NOT NULL DEFAULT 0, -- 当日是否已沉淀
  settled_at      TEXT,
  entity_count    INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
