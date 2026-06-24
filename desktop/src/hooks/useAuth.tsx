import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { USE_MOCK } from '../mock';
import { fetchMe, login as apiLogin, register as apiRegister, upsertDevice } from '../services/auth';
import {
  AUTH_EXPIRED_EVENT,
  clearAuth,
  getStoredUser,
  getToken,
  setStoredUser,
  setToken,
} from '../services/authToken';
import { setLocalMode } from '../services/runtimeMode';
import { getDeviceId } from '../services/vault';
import type { AuthStatus, AuthUser } from '../shared/types/auth';

interface AuthContextValue {
  status: AuthStatus;
  user: AuthUser | null;
  /** 登录；成功返回 null，失败返回错误信息。 */
  login: (username: string, password: string) => Promise<string | null>;
  /** 注册；成功返回 null，失败返回错误信息。 */
  register: (username: string, password: string, email?: string) => Promise<string | null>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const MOCK_USER: AuthUser = { id: 1, username: 'mock', email: null };

async function registerCurrentDevice(): Promise<void> {
  try {
    await upsertDevice({
      deviceId: getDeviceId(),
      name: typeof navigator !== 'undefined' ? navigator.userAgent.slice(0, 80) : 'LifeScale Desktop',
      platform: 'desktop',
    });
  } catch {
    // 设备注册只用于同步状态解释，失败不阻塞登录。
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>('loading');
  const [user, setUser] = useState<AuthUser | null>(null);

  useEffect(() => {
    let cancelled = false;

    const enterLocalMode = () => {
      setLocalMode(true);
      setUser(null);
      setStatus('local');
    };

    const acceptUser = (nextUser: AuthUser) => {
      setLocalMode(false);
      setStoredUser(nextUser);
      setUser(nextUser);
      setStatus('authenticated');
    };

    async function init() {
      if (USE_MOCK) {
        // mock 模式预置会话，避免被登录挡住无后端开发
        acceptUser(MOCK_USER);
        return;
      }
      const token = getToken();
      if (!token) {
        // 真实模式无 token：进入本地态（纯本地使用，不请求云端）
        enterLocalMode();
        return;
      }

      const storedUser = getStoredUser();
      if (storedUser) {
        // 离线优先：本地已有会话摘要时立即进入应用，后台再 best-effort 校验 token。
        acceptUser(storedUser);
      }

      let res: Awaited<ReturnType<typeof fetchMe>>;
      try {
        res = await fetchMe();
      } catch {
        if (!storedUser) {
          enterLocalMode();
        }
        return;
      }
      if (cancelled) {
        return;
      }
      if (res.success && res.data) {
        acceptUser(res.data);
        void registerCurrentDevice();
      } else if (res.code === 401) {
        // 只有明确鉴权失效才清会话；网络不可达/后端关闭不阻塞离线使用。
        clearAuth();
        enterLocalMode();
      } else if (!storedUser) {
        enterLocalMode();
      } else {
        setLocalMode(false);
      }
    }
    void init();
    return () => {
      cancelled = true;
    };
  }, []);

  // 监听 401 失效事件（client.ts 派发）→ 回到本地态
  useEffect(() => {
    const onExpired = () => {
      setLocalMode(true);
      clearAuth();
      setUser(null);
      setStatus('local');
    };
    window.addEventListener(AUTH_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(AUTH_EXPIRED_EVENT, onExpired);
  }, []);

  const login = useCallback(async (username: string, password: string): Promise<string | null> => {
    const res = await apiLogin(username, password);
    if (res.success && res.data) {
      const u: AuthUser = { id: res.data.userId, username: res.data.username, email: res.data.email };
      setToken(res.data.token);
      setStoredUser(u);
      setUser(u);
      setLocalMode(false);
      setStatus('authenticated');
      void registerCurrentDevice();
      return null;
    }
    return res.message || '登录失败';
  }, []);

  const register = useCallback(
    async (username: string, password: string, email?: string): Promise<string | null> => {
      const res = await apiRegister(username, password, email);
      if (res.success && res.data) {
        const u: AuthUser = { id: res.data.userId, username: res.data.username, email: res.data.email };
        setToken(res.data.token);
        setStoredUser(u);
        setUser(u);
        setLocalMode(false);
        setStatus('authenticated');
        void registerCurrentDevice();
        return null;
      }
      return res.message || '注册失败';
    },
    [],
  );

  const logout = useCallback(() => {
    clearAuth();
    setUser(null);
    if (USE_MOCK) {
      setStoredUser(MOCK_USER);
      setUser(MOCK_USER);
      setLocalMode(false);
      setStatus('authenticated');
    } else {
      // 真实模式退出登录 → 回到本地态（继续纯本地可用）
      setLocalMode(true);
      setStatus('local');
    }
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ status, user, login, register, logout }),
    [status, user, login, register, logout],
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
