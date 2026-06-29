import { Avatar, Button, Empty, Input, List, Modal, Segmented, Skeleton, Tag, message } from 'antd';
import {
  CloudOutlined,
  DatabaseOutlined,
  FolderOpenOutlined,
  LoginOutlined,
  LogoutOutlined,
  SaveOutlined,
  SettingOutlined,
  UserOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { useMarkdownSettings } from '../../hooks/useMarkdownSettings';
import { useUserProfile } from '../../hooks/useUserProfile';
import type { SettingsSection } from '../../hooks/useSettingsModal';
import type { RequestStatus } from '../../shared/types/api';
import type { AuthStatus, AuthUser } from '../../shared/types/auth';
import type { DailyMarkdownListData, MarkdownSettings } from '../../shared/types/dailyMarkdown';
import { formatDate } from '../../shared/utils/date';

interface SettingsCenterModalProps {
  open: boolean;
  activeSection: SettingsSection;
  onSectionChange: (section: SettingsSection) => void;
  onClose: () => void;
}

interface SettingsSectionHeaderProps {
  titleId?: string;
  icon: ReactNode;
  title: string;
  description: string;
  extra?: ReactNode;
}

interface ProfileSectionProps {
  isAuthenticated: boolean;
  authUser: AuthUser | null;
  onGoToSync: () => void;
}

type AuthMode = 'login' | 'register';

interface AuthModalProps {
  open: boolean;
  mode: AuthMode;
  onModeChange: (mode: AuthMode) => void;
  onClose: () => void;
}

interface SyncSectionProps {
  authStatus: AuthStatus;
  authUser: AuthUser | null;
  onLogout: () => void;
  onGoToProfile: () => void;
}

interface SpaceSectionProps {
  settings: MarkdownSettings | null;
  recentDocuments: DailyMarkdownListData | null;
  status: RequestStatus;
  choosing: boolean;
  saving: boolean;
  error: string | null;
  hasSaveRoot: boolean;
  dailySubdirInput: string;
  previewPath: string;
  onDailySubdirChange: (value: string) => void;
  onChooseRootFolder: () => Promise<MarkdownSettings | null>;
  onSaveDailySubdir: () => void;
}

const SETTINGS_SECTIONS: Array<{
  key: SettingsSection;
  label: string;
  description: string;
  icon: ReactNode;
}> = [
  {
    key: 'profile',
    label: '个人信息',
    description: '账号、资料与每日提示',
    icon: <UserOutlined />,
  },
  {
    key: 'sync',
    label: '云同步',
    description: '同步状态与账号',
    icon: <CloudOutlined />,
  },
  {
    key: 'space',
    label: '空间设置',
    description: 'Markdown 保存位置',
    icon: <DatabaseOutlined />,
  },
];

function joinPreviewPath(rootPath: string, relativePath: string): string {
  const cleanRoot = rootPath.trim().replace(/[\\/]+$/, '');
  if (!cleanRoot) {
    return relativePath;
  }
  const separator = cleanRoot.includes('\\') ? '\\' : '/';
  return `${cleanRoot}${separator}${relativePath.replace(/\//g, separator)}`;
}

function SettingsSectionHeader({
  titleId,
  icon,
  title,
  description,
  extra,
}: SettingsSectionHeaderProps) {
  return (
    <div className="settings-center-section-header">
      <div className="settings-center-heading-copy">
        <span className="settings-center-heading-icon">{icon}</span>
        <div>
          <h2 id={titleId}>{title}</h2>
          <p>{description}</p>
        </div>
      </div>
      {extra}
    </div>
  );
}

/**
 * 登录 / 注册独立弹窗。封装全部鉴权表单逻辑（用户名/密码/邮箱/错误/提交），
 * 由 ProfileSection 通过 open/mode 控制显隐，登录/注册成功后自动关闭。
 */
function AuthModal({ open, mode, onModeChange, onClose }: AuthModalProps) {
  const { login, register } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 切换登录/注册时清空错误与已填敏感字段
  useEffect(() => {
    if (open) {
      setError(null);
    }
  }, [open, mode]);

  const handleSubmit = useCallback(
    async (event: React.FormEvent) => {
      event.preventDefault();
      if (!username.trim() || !password) {
        setError('请输入用户名和密码');
        return;
      }
      setSubmitting(true);
      setError(null);
      try {
        const err =
          mode === 'login'
            ? await login(username.trim(), password)
            : await register(username.trim(), password, email.trim() || undefined);
        if (err) {
          setError(err);
          return;
        }
        message.success(mode === 'login' ? '登录成功' : '注册成功');
        setUsername('');
        setPassword('');
        setEmail('');
        onClose();
      } finally {
        setSubmitting(false);
      }
    },
    [mode, email, password, username, login, register, onClose],
  );

  return (
    <Modal
      open={open}
      onCancel={onClose}
      footer={null}
      width={400}
      centered
      destroyOnHidden
      title={mode === 'login' ? '登录账号' : '注册新账号'}
    >
      <div className="settings-center-auth-modal">
        <Segmented
          block
          value={mode}
          onChange={(value) => onModeChange(value as AuthMode)}
          options={[
            { label: '登录', value: 'login' },
            { label: '注册', value: 'register' },
          ]}
        />

        <form className="settings-center-auth-form" onSubmit={handleSubmit}>
          <label className="settings-field-label" htmlFor="settings-auth-username">
            用户名
            <Input
              id="settings-auth-username"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              placeholder="请输入用户名"
              autoComplete="username"
              disabled={submitting}
            />
          </label>
          <label className="settings-field-label" htmlFor="settings-auth-password">
            密码
            <Input.Password
              id="settings-auth-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder={mode === 'register' ? '至少 8 位，含字母与数字' : '请输入密码'}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              disabled={submitting}
            />
          </label>
          {mode === 'register' && (
            <label className="settings-field-label" htmlFor="settings-auth-email">
              邮箱（可选）
              <Input
                id="settings-auth-email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="可选，用于找回账号"
                autoComplete="email"
                disabled={submitting}
              />
            </label>
          )}
          {error && <p className="settings-center-auth-error">{error}</p>}
          <Button
            type="primary"
            htmlType="submit"
            icon={<LoginOutlined />}
            loading={submitting}
            block
          >
            {mode === 'login' ? '登录' : '注册并登录'}
          </Button>
        </form>
      </div>
    </Modal>
  );
}

/** 个人信息页：未登录显示状态卡片；已登录显示可编辑资料（纵向布局）。 */
function ProfileSection({ isAuthenticated, authUser, onGoToSync }: ProfileSectionProps) {
  const { profile, status, saving, updateProfile } = useUserProfile();

  // 鉴权弹窗控制（表单逻辑封装在 AuthModal 内部）
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [authMode, setAuthMode] = useState<AuthMode>('login');

  // 资料编辑表单状态（已登录）
  const [nickname, setNickname] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [greeting, setGreeting] = useState('');
  const [motivationalQuote, setMotivationalQuote] = useState('');

  // 已登录：资料加载后同步到编辑框
  useEffect(() => {
    if (isAuthenticated) {
      setNickname(profile.nickname ?? '');
      setAvatarUrl(profile.avatarUrl ?? '');
      setGreeting(profile.greeting ?? '');
      setMotivationalQuote(profile.motivationalQuote ?? '');
    }
  }, [isAuthenticated, profile]);

  const handleSaveProfile = useCallback(async () => {
    const err = await updateProfile({
      nickname: nickname.trim(),
      avatarUrl: avatarUrl.trim(),
      greeting: greeting.trim(),
      motivationalQuote: motivationalQuote.trim(),
    });
    if (err) {
      message.error(err);
    } else {
      message.success('个人资料已保存');
    }
  }, [avatarUrl, greeting, motivationalQuote, nickname, updateProfile]);

  // ---- 未登录：状态卡片 + 登录/注册按钮（点击弹独立窗） ----
  if (!isAuthenticated) {
    return (
      <section className="settings-center-section" aria-labelledby="settings-profile-title">
        <SettingsSectionHeader
          titleId="settings-profile-title"
          icon={<UserOutlined />}
          title="个人信息"
          description="登录后即可编辑头像、昵称、问候语和每日提示，并开启多端云同步。未登录时使用默认提示。"
        />

        <div className="settings-center-guest">
          <Avatar size={76} icon={<UserOutlined />} className="settings-center-guest-avatar" />
          <h3>未登录</h3>
          <p>登录后可编辑个人资料，并开启多端云同步；未登录也能完整使用今日、日历、复盘与本地笔记。</p>
          <div className="settings-center-guest-actions">
            <Button
              type="primary"
              icon={<LoginOutlined />}
              onClick={() => {
                setAuthMode('login');
                setAuthModalOpen(true);
              }}
            >
              登录
            </Button>
            <Button
              onClick={() => {
                setAuthMode('register');
                setAuthModalOpen(true);
              }}
            >
              注册
            </Button>
          </div>
        </div>

        <AuthModal
          open={authModalOpen}
          mode={authMode}
          onModeChange={setAuthMode}
          onClose={() => setAuthModalOpen(false)}
        />
      </section>
    );
  }

  // ---- 已登录：可编辑资料（纵向布局） ----
  const profileLoading = status === 'loading';
  const displayName = profile.nickname?.trim() || authUser?.username || '用户';

  return (
    <section className="settings-center-section" aria-labelledby="settings-profile-title">
      <SettingsSectionHeader
        titleId="settings-profile-title"
        icon={<UserOutlined />}
        title="个人信息"
        description="编辑你的头像、昵称、问候语和每日提示，保存后会同步到云端，多端生效。"
        extra={<Tag color="green">已登录</Tag>}
      />

      {profileLoading ? (
        <Skeleton active avatar paragraph={{ rows: 4 }} />
      ) : (
        <div className="settings-center-profile">
          <div className="settings-center-profile-head">
            <Avatar
              size={72}
              src={avatarUrl.trim() || undefined}
              className="settings-center-avatar"
            >
              {displayName.charAt(0)}
            </Avatar>
            <div>
              <span className="settings-center-kicker">当前昵称</span>
              <strong>{displayName}</strong>
              <p>{authUser?.email ?? '账号已连接云同步。'}</p>
            </div>
          </div>

          <label className="settings-field-label" htmlFor="settings-profile-nickname">
            昵称
            <Input
              id="settings-profile-nickname"
              value={nickname}
              onChange={(event) => setNickname(event.target.value)}
              placeholder="设置一个展示昵称"
              disabled={saving}
            />
          </label>

          <label className="settings-field-label" htmlFor="settings-profile-avatar">
            头像地址
            <Input
              id="settings-profile-avatar"
              value={avatarUrl}
              onChange={(event) => setAvatarUrl(event.target.value)}
              placeholder="粘贴头像图片 URL，留空则按昵称首字显示"
              disabled={saving}
            />
          </label>

          <label className="settings-field-label" htmlFor="settings-profile-greeting">
            问候语
            <Input
              id="settings-profile-greeting"
              value={greeting}
              onChange={(event) => setGreeting(event.target.value)}
              placeholder="如：早安"
              disabled={saving}
            />
          </label>

          <label className="settings-field-label" htmlFor="settings-profile-quote">
            每日提示
            <Input.TextArea
              id="settings-profile-quote"
              value={motivationalQuote}
              onChange={(event) => setMotivationalQuote(event.target.value)}
              placeholder="一句每日激励自己的话"
              autoSize={{ minRows: 2, maxRows: 4 }}
              disabled={saving}
            />
          </label>

          <div className="settings-center-profile-actions">
            <Button type="primary" icon={<SaveOutlined />} loading={saving} onClick={handleSaveProfile}>
              保存资料
            </Button>
            <Button type="link" onClick={onGoToSync}>
              管理云同步与账号 →
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}

/** 云同步页：仅显示同步状态与账号（登录入口在个人信息页）。纵向布局。 */
function SyncSection({ authStatus, authUser, onLogout, onGoToProfile }: SyncSectionProps) {
  const isAuthenticated = authStatus === 'authenticated';

  return (
    <section className="settings-center-section" aria-labelledby="settings-sync-title">
      <SettingsSectionHeader
        titleId="settings-sync-title"
        icon={<CloudOutlined />}
        title="云同步"
        description="本地 Markdown 文件夹始终是事实来源；登录只开启云端镜像与多端同步。"
        extra={
          <Tag color={isAuthenticated ? 'green' : 'blue'}>
            {isAuthenticated ? '云同步已开启' : '本地模式'}
          </Tag>
        }
      />

      <article
        className={`settings-center-sync-hero${isAuthenticated ? ' is-cloud' : ' is-local'}`}
      >
        <span className="settings-center-sync-icon" aria-hidden="true">
          {isAuthenticated ? <CloudOutlined /> : <CloudOutlined />}
        </span>
        <div>
          <span className="settings-center-kicker">当前模式</span>
          <h3>{isAuthenticated ? '云同步已开启' : '本地优先模式'}</h3>
          <p>
            {isAuthenticated
              ? '当前工作区会作为云端账号空间的镜像，换设备后登录同一账号即可继续拉取使用。'
              : '不登录也能完整使用今日、日历、复盘和本地笔记。前往个人信息页登录后即可开启云端同步。'}
          </p>
        </div>
      </article>

      {isAuthenticated ? (
        <article className="settings-center-account-row">
          <div className="settings-center-account-info">
            <span className="settings-center-kicker">已登录账号</span>
            <strong>{authUser?.username ?? '云端用户'}</strong>
            <p>{authUser?.email ?? '当前账号已连接云同步。'}</p>
          </div>
          <Button icon={<LogoutOutlined />} onClick={onLogout} danger>
            退出登录
          </Button>
        </article>
      ) : (
        <article className="settings-center-account-row is-local">
          <div className="settings-center-account-info">
            <span className="settings-center-kicker">未登录</span>
            <strong>当前为本地模式</strong>
            <p>数据只保存在本机。前往个人信息页登录或注册后，即可开启云端同步。</p>
          </div>
          <Button type="primary" onClick={onGoToProfile}>
            去登录 / 注册
          </Button>
        </article>
      )}
    </section>
  );
}

/** 空间设置页：仅保留本地保存位置相关，移除服务器镜像目录等后端实现细节。纵向布局。 */
function SpaceSection({
  settings,
  recentDocuments,
  status,
  choosing,
  saving,
  error,
  hasSaveRoot,
  dailySubdirInput,
  previewPath,
  onDailySubdirChange,
  onChooseRootFolder,
  onSaveDailySubdir,
}: SpaceSectionProps) {
  const settingsLoading = status === 'loading' && !settings;

  return (
    <section className="settings-center-section" aria-labelledby="settings-space-title">
      <SettingsSectionHeader
        titleId="settings-space-title"
        icon={<DatabaseOutlined />}
        title="空间设置"
        description="管理当前空间的 Markdown 保存位置，复盘保存后会写入每日文档。"
        extra={<Tag color={hasSaveRoot ? 'green' : 'orange'}>{hasSaveRoot ? '已设置' : '待设置'}</Tag>}
      />

      {error && <div className="settings-center-error">{error}</div>}

      {settingsLoading ? (
        <Skeleton active paragraph={{ rows: 6 }} />
      ) : (
        <div className="settings-center-space">
          <div className="settings-center-space-block">
            <span className="settings-field-label">Markdown 保存根目录</span>
            <strong className={!settings?.saveRootPath ? 'is-muted' : undefined}>
              {settings?.saveRootPath || '尚未选择文件夹'}
            </strong>
            <p>选择后，保存复盘会自动生成或覆盖当天文件。</p>
            <Button
              type="primary"
              icon={<FolderOpenOutlined />}
              loading={choosing || saving}
              disabled={!settings?.permissions.canChooseFolder}
              onClick={() => void onChooseRootFolder()}
            >
              选择文件夹
            </Button>
          </div>

          <div className="settings-center-space-block">
            <span className="settings-field-label">每日记录子目录名</span>
            <Input
              value={dailySubdirInput}
              onChange={(event) => onDailySubdirChange(event.target.value)}
              placeholder="Daily"
              disabled={!settings?.permissions.canChooseFolder || saving}
            />
            <p>默认 Daily；改名后旧文件夹下的本地文件需手动重命名或重新同步。</p>
            <Button
              icon={<SaveOutlined />}
              loading={saving}
              disabled={!settings?.permissions.canChooseFolder}
              onClick={onSaveDailySubdir}
            >
              保存子目录名
            </Button>
          </div>

          <div className="settings-center-space-block">
            <span className="settings-field-label">今日输出路径</span>
            <strong className={hasSaveRoot ? undefined : 'is-muted'}>{previewPath}</strong>
            <p>固定结构：Daily/YYYY-MM-DD.md；同一天多次保存会覆盖同一个文件。</p>
          </div>

          <div className="settings-center-space-block">
            <div className="settings-center-compact-heading">
              <h3>最近每日文档</h3>
              <p>展示最近成功保存到磁盘的 Markdown 文件。</p>
            </div>

            {recentDocuments?.list.length ? (
              <List
                className="settings-center-recent-list"
                dataSource={recentDocuments.list}
                renderItem={(item) => (
                  <List.Item>
                    <div className="settings-center-recent-item">
                      <strong>{item.title}</strong>
                      <span>{item.relativePath}</span>
                      <time dateTime={item.savedAt}>
                        {dayjs(item.savedAt).format('YYYY-MM-DD HH:mm')}
                      </time>
                    </div>
                  </List.Item>
                )}
              />
            ) : (
              <Empty
                image={Empty.PRESENTED_IMAGE_SIMPLE}
                description="暂无已保存的每日 Markdown"
                className="settings-center-empty"
              />
            )}
          </div>
        </div>
      )}
    </section>
  );
}

export function SettingsCenterModal({
  open,
  activeSection,
  onSectionChange,
  onClose,
}: SettingsCenterModalProps) {
  const { status: authStatus, user: authUser, logout } = useAuth();
  const {
    settings,
    recentDocuments,
    status,
    choosing,
    saving,
    error,
    hasSaveRoot,
    chooseRootFolder,
    updateSettings,
  } = useMarkdownSettings();

  const [dailySubdirInput, setDailySubdirInput] = useState('');

  useEffect(() => {
    setDailySubdirInput(settings?.dailySubdirectory ?? 'Daily');
  }, [settings?.dailySubdirectory]);

  const todayRelativePath = useMemo(() => {
    const pattern = settings?.dailyPathPattern ?? 'Daily/YYYY-MM-DD.md';
    return pattern.replace('YYYY-MM-DD', formatDate());
  }, [settings?.dailyPathPattern]);

  const previewPath = settings?.saveRootPath
    ? joinPreviewPath(settings.saveRootPath, todayRelativePath)
    : todayRelativePath;

  const handleLogout = useCallback(() => {
    logout();
    message.success('已退出登录，回到本地模式');
  }, [logout]);

  const handleSaveDailySubdir = useCallback(() => {
    const name = dailySubdirInput.trim() || 'Daily';
    const current = settings?.dailySubdirectory ?? 'Daily';
    if (name === current) {
      void updateSettings({ dailySubdirectory: name });
      return;
    }
    Modal.confirm({
      title: '修改每日记录子目录名？',
      content: `改名后，旧「${current}」文件夹下的本地 Markdown 文件需手动重命名或重新同步，新内容会写入「${name}」。`,
      okText: '确认改名',
      cancelText: '取消',
      centered: true,
      onOk: () => void updateSettings({ dailySubdirectory: name }),
    });
  }, [dailySubdirInput, settings?.dailySubdirectory, updateSettings]);

  const isAuthenticated = authStatus === 'authenticated';

  return (
    <Modal
      open={open}
      footer={null}
      width={980}
      centered
      onCancel={onClose}
      className="settings-center-modal"
      title={null}
    >
      <div className="settings-center-shell">
        <aside className="settings-center-sidebar" aria-label="设置分类">
          <div className="settings-center-brand">
            <span className="settings-center-brand-icon">
              <SettingOutlined />
            </span>
            <div>
              <strong>设置中心</strong>
              <span>本地优先，云端可选</span>
            </div>
          </div>

          <nav className="settings-center-nav">
            {SETTINGS_SECTIONS.map((item) => {
              const isActive = item.key === activeSection;
              return (
                <button
                  key={item.key}
                  type="button"
                  className={`settings-center-nav-item${isActive ? ' is-active' : ''}`}
                  onClick={() => onSectionChange(item.key)}
                >
                  <span className="settings-center-nav-icon">{item.icon}</span>
                  <span>
                    <strong>{item.label}</strong>
                    <small>{item.description}</small>
                  </span>
                </button>
              );
            })}
          </nav>
        </aside>

        <main className="settings-center-content">
          {activeSection === 'profile' ? (
            <ProfileSection
              isAuthenticated={isAuthenticated}
              authUser={authUser}
              onGoToSync={() => onSectionChange('sync')}
            />
          ) : activeSection === 'sync' ? (
            <SyncSection
              authStatus={authStatus}
              authUser={authUser}
              onLogout={handleLogout}
              onGoToProfile={() => onSectionChange('profile')}
            />
          ) : (
            <SpaceSection
              settings={settings}
              recentDocuments={recentDocuments}
              status={status}
              choosing={choosing}
              saving={saving}
              error={error}
              hasSaveRoot={hasSaveRoot}
              dailySubdirInput={dailySubdirInput}
              previewPath={previewPath}
              onDailySubdirChange={setDailySubdirInput}
              onChooseRootFolder={chooseRootFolder}
              onSaveDailySubdir={handleSaveDailySubdir}
            />
          )}
        </main>
      </div>
    </Modal>
  );
}
