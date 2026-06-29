import { useCallback, useState } from 'react';
import type { RequestStatus } from '../shared/types/api';
import type { UpdateUserProfilePayload, UserProfile } from '../shared/types/userProfile';
import { DEFAULT_USER_PROFILE } from '../shared/types/userProfile';
import { useAuth } from './useAuth';

interface UseUserProfileResult {
  profile: UserProfile;
  /** 开源本地版恒为 false（无登录态）。保留以兼容消费方。 */
  isAuthenticated: boolean;
  status: RequestStatus;
  error: string | null;
  saving: boolean;
  refetch: () => Promise<void>;
  updateProfile: (payload: UpdateUserProfilePayload) => Promise<string | null>;
}

const NICKNAME_KEY = 'lifescale.local.nickname';

/**
 * 用户资料 hook（开源本地版）。
 *
 * 私有版拉取/更新云端 `/api/user/profile`；开源版已移除全部网络逻辑，
 * 昵称来自本地资料（与 useAuth 共用 localStorage 键），其余字段用默认值，
 * updateProfile 仅写本地昵称。
 */
export function useUserProfile(): UseUserProfileResult {
  const { user } = useAuth();
  const [saving, setSaving] = useState(false);

  const profile: UserProfile = {
    ...DEFAULT_USER_PROFILE,
    nickname: user.username,
  };

  const refetch = useCallback(async () => {
    /* 本地版无远程资料，无需拉取。 */
  }, []);

  const updateProfile = useCallback(
    async (payload: UpdateUserProfilePayload): Promise<string | null> => {
      if (payload.nickname != null) {
        const name = payload.nickname.trim();
        try {
          localStorage.setItem(NICKNAME_KEY, name);
        } catch {
          /* ignore */
        }
        // 触发 useAuth 重新读取昵称（通过刷新页面状态由调用方处理；此处仅持久化）。
      }
      setSaving(true);
      setSaving(false);
      return null;
    },
    [],
  );

  return {
    profile,
    isAuthenticated: false,
    status: 'success',
    error: null,
    saving,
    refetch,
    updateProfile,
  };
}
