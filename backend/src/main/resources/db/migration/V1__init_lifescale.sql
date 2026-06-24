-- ============================================================================
-- LifeScale 初始化 Schema（全量基线 V1）
-- ============================================================================
-- 架构模型：Model A —— 本地优先 Markdown Vault 同步
--   本地 Markdown 文件是事实来源，PostgreSQL 只存索引与元数据，正文存 CAS（内容寻址存储）。
--
-- 本文件整合自原 V12（auth_user_device）、V13（vault_index）、V15（attachment）。
-- 原 Model B 遗留表（ls_date_entity / ls_schedule / ls_quick_note / ls_daily_review /
-- ls_review_* / ls_daily_document / ls_markdown_setting / ls_kb_* / ls_time_period / ls_sync）
-- 已随 Model B 后端代码整体废弃删除，新部署不再创建。
--
-- 约定（与历史迁移一致）：
--   - 表前缀 ls_
--   - 严格不使用外键（逻辑关联，应用层维护）
--   - 时间字段统一 TIMESTAMPTZ，默认 now()
--   - 软删除用 status 字段（active / deleted），不做物理删除
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. 用户账号表（多端同步归属主体）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_user (
  id            BIGSERIAL     PRIMARY KEY,
  username      VARCHAR(64)   NOT NULL UNIQUE,
  email         VARCHAR(128)  NULL UNIQUE,
  password_hash VARCHAR(100)  NOT NULL,                     -- BCrypt 哈希，明文不落库
  status        VARCHAR(20)   NOT NULL DEFAULT 'active',    -- active / disabled
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

COMMENT ON TABLE  ls_user              IS '用户账号表，多端同步归属主体';
COMMENT ON COLUMN ls_user.id           IS '自增主键';
COMMENT ON COLUMN ls_user.username     IS '用户名，唯一';
COMMENT ON COLUMN ls_user.email        IS '邮箱，可空，唯一';
COMMENT ON COLUMN ls_user.password_hash IS 'BCrypt 密码哈希，明文不落库';
COMMENT ON COLUMN ls_user.status       IS '账号状态：active 活跃 / disabled 禁用';
COMMENT ON COLUMN ls_user.created_at   IS '创建时间';
COMMENT ON COLUMN ls_user.updated_at   IS '最后更新时间';


-- ----------------------------------------------------------------------------
-- 2. 设备注册表（多端身份与同步游标归属）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_device (
  id              BIGSERIAL    PRIMARY KEY,
  user_id         BIGINT       NOT NULL,                    -- 归属用户（逻辑外键，无约束）
  device_id       VARCHAR(64)  NOT NULL,                    -- 客户端生成的稳定 UUID
  name            VARCHAR(100) NULL,                        -- 设备名（如「Kai 的 MacBook」）
  platform        VARCHAR(20)  NULL,                        -- desktop / mobile
  last_synced_at  TIMESTAMPTZ  NULL,                        -- 最近一次成功同步时间
  last_seen_at    TIMESTAMPTZ  NULL,                        -- 最近一次心跳时间
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE INDEX idx_device_user ON ls_device (user_id);

COMMENT ON TABLE  ls_device               IS '设备注册表，多端身份与同步游标归属';
COMMENT ON COLUMN ls_device.user_id       IS '归属用户 ID（逻辑外键，关联 ls_user.id）';
COMMENT ON COLUMN ls_device.device_id     IS '客户端生成的稳定设备 UUID';
COMMENT ON COLUMN ls_device.name          IS '设备名（如「Kai 的 MacBook」）';
COMMENT ON COLUMN ls_device.platform      IS '平台：desktop 桌面端 / mobile 移动端';
COMMENT ON COLUMN ls_device.last_synced_at IS '最近一次成功同步时间';
COMMENT ON COLUMN ls_device.last_seen_at  IS '最近一次心跳时间';
COMMENT ON COLUMN ls_device.created_at    IS '创建时间';
COMMENT ON COLUMN ls_device.updated_at    IS '最后更新时间';


-- ----------------------------------------------------------------------------
-- 3. 远端 Vault 文件索引（每个用户、每个路径一行；删除为墓碑 status=deleted）
--    同步单位 = vault 相对路径 + 内容 hash（.md 文件保持纯净，元数据落库）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_vault_file (
  id                     BIGSERIAL     PRIMARY KEY,
  user_id                BIGINT        NOT NULL,            -- 归属用户（逻辑外键）
  vault_path             VARCHAR(500)  NOT NULL,            -- 如 Daily/2026-06-16.md、Notes/项目A/需求.md
  content_hash           VARCHAR(64)   NOT NULL,            -- SHA-256，指向 CAS 内容
  size_bytes             BIGINT        NOT NULL DEFAULT 0,
  version                INT           NOT NULL DEFAULT 1,  -- 单调递增版本号
  status                 VARCHAR(20)   NOT NULL DEFAULT 'active', -- active / deleted(墓碑)
  last_modified_device_id VARCHAR(64)  NULL,
  created_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (user_id, vault_path)
);

CREATE INDEX idx_vault_file_changes ON ls_vault_file (user_id, updated_at);

COMMENT ON TABLE  ls_vault_file                       IS '远端 vault 文件索引：路径+hash+版本+墓碑，/api/vault/changes 按 updated_at 游标';
COMMENT ON COLUMN ls_vault_file.user_id               IS '归属用户 ID（逻辑外键）';
COMMENT ON COLUMN ls_vault_file.vault_path            IS 'vault 相对路径，如 Daily/2026-06-16.md';
COMMENT ON COLUMN ls_vault_file.content_hash          IS '内容 SHA-256，指向 CAS 存储';
COMMENT ON COLUMN ls_vault_file.size_bytes            IS '文件字节数';
COMMENT ON COLUMN ls_vault_file.version               IS '单调递增版本号';
COMMENT ON COLUMN ls_vault_file.status                IS '状态：active 活跃 / deleted 墓碑（删除传播）';
COMMENT ON COLUMN ls_vault_file.last_modified_device_id IS '最近修改设备 ID';
COMMENT ON COLUMN ls_vault_file.created_at            IS '创建时间';
COMMENT ON COLUMN ls_vault_file.updated_at            IS '最后更新时间（changes 游标依据）';


-- ----------------------------------------------------------------------------
-- 4. Vault 版本历史（每次成功写入/合并建一行；三方合并用 content_hash 反查 base）
-- ----------------------------------------------------------------------------
CREATE TABLE ls_vault_version (
  id           BIGSERIAL    PRIMARY KEY,
  user_id      BIGINT       NOT NULL,
  vault_path   VARCHAR(500) NOT NULL,
  version      INT          NOT NULL,
  content_hash VARCHAR(64)  NOT NULL,
  size_bytes   BIGINT       NOT NULL DEFAULT 0,
  device_id    VARCHAR(64)  NULL,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (user_id, vault_path, version)
);

CREATE INDEX idx_vault_version_hash ON ls_vault_version (content_hash);

COMMENT ON TABLE  ls_vault_version               IS 'vault 版本历史：三方合并 base 反查 + 未来历史版本 UI';
COMMENT ON COLUMN ls_vault_version.user_id       IS '归属用户 ID';
COMMENT ON COLUMN ls_vault_version.vault_path    IS 'vault 相对路径';
COMMENT ON COLUMN ls_vault_version.version       IS '版本号';
COMMENT ON COLUMN ls_vault_version.content_hash  IS '该版本内容 SHA-256';
COMMENT ON COLUMN ls_vault_version.size_bytes    IS '文件字节数';
COMMENT ON COLUMN ls_vault_version.device_id     IS '产生该版本的设备 ID';
COMMENT ON COLUMN ls_vault_version.created_at    IS '创建时间';


-- ----------------------------------------------------------------------------
-- 5. Vault 冲突记录（无法自动合并时落一条；冲突副本以独立 vault_path 存在）
--    核心原则：永不丢数据。服务端正本不被覆盖，本地内容落冲突副本。
-- ----------------------------------------------------------------------------
CREATE TABLE ls_vault_conflict (
  id                 BIGSERIAL    PRIMARY KEY,
  user_id            BIGINT       NOT NULL,
  vault_path         VARCHAR(500) NOT NULL,
  base_version       INT          NULL,
  mine_hash          VARCHAR(64)  NULL,
  theirs_hash        VARCHAR(64)  NULL,
  merged_hash        VARCHAR(64)  NULL,                     -- NULL=未合并，已生成冲突副本
  conflict_copy_path VARCHAR(500) NULL,                     -- 如 Notes/x.conflict-20260616T1030.md
  status             VARCHAR(20)  NOT NULL DEFAULT 'open',  -- open / resolved
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_vault_conflict_user ON ls_vault_conflict (user_id, status);

COMMENT ON TABLE  ls_vault_conflict                    IS 'vault 冲突记录，配合冲突副本文件保留双方内容';
COMMENT ON COLUMN ls_vault_conflict.user_id            IS '归属用户 ID';
COMMENT ON COLUMN ls_vault_conflict.vault_path         IS '冲突文件路径';
COMMENT ON COLUMN ls_vault_conflict.base_version       IS '冲突时的基准版本号';
COMMENT ON COLUMN ls_vault_conflict.mine_hash          IS '客户端推送内容 hash';
COMMENT ON COLUMN ls_vault_conflict.theirs_hash        IS '服务端当前正本 hash';
COMMENT ON COLUMN ls_vault_conflict.merged_hash        IS '合并后 hash，NULL 表示未合并';
COMMENT ON COLUMN ls_vault_conflict.conflict_copy_path IS '冲突副本路径（独立 .md 文件）';
COMMENT ON COLUMN ls_vault_conflict.status             IS '冲突状态：open 待处理 / resolved 已解决';
COMMENT ON COLUMN ls_vault_conflict.created_at         IS '创建时间';


-- ----------------------------------------------------------------------------
-- 6. 附件内容寻址元数据表
--    附件正文按 SHA-256 存在 CAS（<cas-root>/att/<hash前2位>/<hash>），此表只记录元数据，
--    为「孤儿 blob 清理（GC）」「按用户枚举附件」「下载归属校验」打基础。
--    内容寻址天然全局去重 → sha256 做 PK；owner 为首次上传者；ref_count 供未来引用计数清理。
--    storage_location 标记附件存储位置（local=磁盘CAS / cos=腾讯云COS），用于混合方案迁移追踪。
-- ----------------------------------------------------------------------------
CREATE TABLE ls_attachment (
  sha256            VARCHAR(64)  PRIMARY KEY,
  size_bytes        BIGINT       NOT NULL,
  owner_user_id     BIGINT       NOT NULL,
  ref_count         INTEGER      NOT NULL DEFAULT 1,
  storage_location  VARCHAR(8)   NOT NULL DEFAULT 'local',  -- local=磁盘CAS / cos=腾讯云COS
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  last_used_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_attachment_owner ON ls_attachment (owner_user_id);

COMMENT ON TABLE  ls_attachment                   IS '附件内容寻址元数据：按 SHA-256 全局去重，owner 为首次上传者，ref_count 供后续孤儿清理';
COMMENT ON COLUMN ls_attachment.sha256            IS '附件内容 SHA-256（与 CAS 存储路径对齐，att/<hash前2位>/<hash>）';
COMMENT ON COLUMN ls_attachment.size_bytes        IS '附件字节数';
COMMENT ON COLUMN ls_attachment.owner_user_id     IS '首次上传者用户 ID（归属/权限）';
COMMENT ON COLUMN ls_attachment.ref_count         IS '引用计数（本阶段仅维护不清理，为 GC 预留）';
COMMENT ON COLUMN ls_attachment.storage_location  IS '附件存储位置：local=磁盘CAS，cos=腾讯云COS（混合方案迁移追踪）';
COMMENT ON COLUMN ls_attachment.created_at        IS '创建时间';
COMMENT ON COLUMN ls_attachment.last_used_at      IS '最近一次下载时间（供未来 LRU 清理）';
