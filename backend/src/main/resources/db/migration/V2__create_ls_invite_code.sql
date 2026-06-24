-- ============================================================================
-- V2：邀请码注册加固（P0-7）
-- ============================================================================
-- 背景：文档 07 原计划用 V16 给 ls_attachment 加 storage_location 字段，但该列
-- 已在合并基线 V1__init_lifescale.sql 中存在（故 P1-6 视为已满足）。本迁移为
-- 邀请码注册加固新建独立表，使用 V2 版本号（非 V16）。
--
-- 模型：任意已登录用户可生成邀请码（POST /api/auth/invite-codes）；陌生人注册时
-- 需提供有效（unused + 未过期）邀请码并被原子核销。MVP 不引入 role 字段。
--
-- 约定：与 V1 一致——表前缀 ls_、无外键（逻辑关联）、TIMESTAMPTZ、状态字段。
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 邀请码表
-- ----------------------------------------------------------------------------
CREATE TABLE ls_invite_code (
  id                 BIGSERIAL    PRIMARY KEY,
  code               VARCHAR(64)  NOT NULL UNIQUE,             -- URL 安全随机 token
  created_by_user_id BIGINT       NOT NULL,                    -- 生成者（逻辑外键，关联 ls_user.id）
  used_by_user_id    BIGINT       NULL,                        -- 使用者（核销时回填）
  status             VARCHAR(20)  NOT NULL DEFAULT 'unused',   -- unused / used / revoked
  expires_at         TIMESTAMPTZ  NULL,                        -- 过期时间（NULL=不过期）
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  used_at            TIMESTAMPTZ  NULL
);

CREATE INDEX idx_invite_code_status ON ls_invite_code (status);
CREATE INDEX idx_invite_code_creator ON ls_invite_code (created_by_user_id);

COMMENT ON TABLE  ls_invite_code                   IS '邀请码注册加固：防陌生人批量注册，MVP 小范围可控';
COMMENT ON COLUMN ls_invite_code.code              IS 'URL 安全随机 token，注册时校验';
COMMENT ON COLUMN ls_invite_code.created_by_user_id IS '生成者用户 ID（任意已登录用户）';
COMMENT ON COLUMN ls_invite_code.used_by_user_id   IS '使用者用户 ID，核销时回填';
COMMENT ON COLUMN ls_invite_code.status            IS '状态：unused 未使用 / used 已使用 / revoked 已撤销';
COMMENT ON COLUMN ls_invite_code.expires_at        IS '过期时间，NULL 表示不过期';
COMMENT ON COLUMN ls_invite_code.created_at        IS '创建时间';
COMMENT ON COLUMN ls_invite_code.used_at           IS '核销时间';
