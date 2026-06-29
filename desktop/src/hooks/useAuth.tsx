import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import type { AuthStatus, AuthUser } from '../shared/types/auth';

/**
 * 本地资料上下文（开源本地版）。
 *
 * 私有版在此承载 JWT 登录/注册/401 失效/云同步开关；开源版已移除全部网络/鉴权逻辑，
 * 仅保留一个本地昵称（localStorage），状态恒为 `local`，供下游组件读取用户展示名。
 * login/register/logout 为空实现，保留接口形状以兼容旧调用点。
 */
interface AuthContextValue {
  status: AuthStatus;
  user: AuthUser;
  login: (username: string, password: string) => Promise<string | null>;
  register: (username: string, password: string, email?: string) => Promise<string | null>;
  logout: () => void;
}

const NICKNAME_KEY = 'lifescale.local.nickname';
const DEFAULT_NICKNAME = '本地用户';

function readNickname(): string {
  try {
    return localStorage.getItem(NICKNAME_KEY) || DEFAULT_NICKNAME;
  } catch {
    return DEFAULT_NICKNAME;
  }
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [nickname, setNickname] = useState<string>(readNickname);

  const user: AuthUser = useMemo(() => ({ id: 1, username: nickname, email: null }), [nickname]);

  const value = useMemo<AuthContextValue>(
    () => ({
      // 恒为 local：下游云同步开关据此关闭（开源版无云同步）。
      status: 'local',
      user,
      // 开源版无远程认证：login/register 仅更新本地昵称；logout 不做任何事。
      login: async (username: string) => {
        const name = username.trim() || DEFAULT_NICKNAME;
        try {
          localStorage.setItem(NICKNAME_KEY, name);
        } catch {
          /* ignore */
        }
        setNickname(name);
        return null;
      },
      register: async (username: string) => {
        const name = username.trim() || DEFAULT_NICKNAME;
        try {
          localStorage.setItem(NICKNAME_KEY, name);
        } catch {
          /* ignore */
        }
        setNickname(name);
        return null;
      },
      logout: () => {
        /* 本地版无登出语义：保持当前昵称。 */
      },
    }),
    [user],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth 必须在 AuthProvider 内使用');
  }
  return ctx;
}
