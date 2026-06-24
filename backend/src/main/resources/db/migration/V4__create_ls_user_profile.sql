-- ============================================================================
-- 用户个人资料表（昵称 / 头像 / 问候语 / 每日提示）
-- ============================================================================
-- 与账号（ls_user）1:1，独立成表以遵循单一职责：ls_user 只管账号与鉴权，
-- 展示型资料（可由用户自行编辑）放本表。注册时由应用层初始化默认行。
--
-- 约定（与 V1/V2/V3 一致）：
--   - 表前缀 ls_
--   - 严格不使用外键（逻辑关联，应用层维护）
--   - 时间字段统一 TIMESTAMPTZ，默认 now()
-- ============================================================================

CREATE TABLE ls_user_profile (
  id                 BIGSERIAL     PRIMARY KEY,
  user_id            BIGINT        NOT NULL,                      -- 归属用户（逻辑外键，关联 ls_user.id）
  nickname           VARCHAR(64)   NOT NULL,                      -- 昵称（展示名）
  avatar_url         VARCHAR(512)  NULL,                          -- 头像 URL（留空则前端按昵称首字渲染）
  greeting           VARCHAR(100)  NOT NULL,                      -- 问候语，如「早安」
  motivational_quote VARCHAR(200)  NOT NULL,                      -- 每日提示 / 励志金句
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

COMMENT ON TABLE  ls_user_profile                   IS '用户个人资料表：可编辑的展示型资料（昵称/头像/问候语/每日提示），与 ls_user 1:1';
COMMENT ON COLUMN ls_user_profile.id                IS '自增主键';
COMMENT ON COLUMN ls_user_profile.user_id           IS '归属用户 ID（逻辑外键，关联 ls_user.id，唯一）';
COMMENT ON COLUMN ls_user_profile.nickname          IS '昵称（展示名），注册时默认取用户名';
COMMENT ON COLUMN ls_user_profile.avatar_url        IS '头像 URL，留空则前端按昵称首字渲染';
COMMENT ON COLUMN ls_user_profile.greeting          IS '问候语，如「早安」';
COMMENT ON COLUMN ls_user_profile.motivational_quote IS '每日提示 / 励志金句';
COMMENT ON COLUMN ls_user_profile.created_at        IS '创建时间';
COMMENT ON COLUMN ls_user_profile.updated_at        IS '最后更新时间';
