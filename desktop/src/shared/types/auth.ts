/** 当前登录用户精简信息。 */
export interface AuthUser {
  id: number;
  username: string;
  email?: string | null;
}

/** 登录/注册成功返回的会话（含 JWT）。 */
export interface AuthSession {
  userId: number;
  username: string;
  email?: string | null;
  token: string;
  expiresAt?: string | null;
}

export interface DeviceRequest {
  deviceId: string;
  name?: string | null;
  platform?: 'desktop' | 'mobile' | string | null;
}

export interface DeviceDTO {
  id: number;
  deviceId: string;
  name?: string | null;
  platform?: string | null;
  lastSyncedAt?: string | null;
  lastSeenAt?: string | null;
}

/**
 * 鉴权运行态：
 * - `loading`：初始化中。
 * - `local`：未登录的稳态——纯本地使用（vault 引擎可用但关闭云同步），不发起任何云端请求。
 * - `authenticated`：已登录、开启云同步。
 * - `unauthenticated`：保留（兼容/兜底），不再作为未登录稳态——未登录即进 `local`。
 */
export type AuthStatus = 'loading' | 'local' | 'authenticated' | 'unauthenticated';
