import { useCallback, useEffect, useState } from 'react';
import type { RequestStatus } from '../shared/types/api';
import type { UpdateUserProfilePayload, UserProfile } from '../shared/types/userProfile';
import { DEFAULT_USER_PROFILE } from '../shared/types/userProfile';
import { getUserProfile, updateUserProfile } from '../services/userProfile';
import { useAuth } from './useAuth';

interface UseUserProfileResult {
  profile: UserProfile;
  /** 是否已登录（资料可编辑、可云同步）。 */
  isAuthenticated: boolean;
  status: RequestStatus;
  error: string | null;
  saving: boolean;
  refetch: () => Promise<void>;
  updateProfile: (payload: UpdateUserProfilePayload) => Promise<string | null>;
}

/**
 * 用户资料 hook。
 * - 未登录（local 模式）：直接返回固定默认资料，不发请求、只读不变。
 * - 已登录：拉取云端资料，支持 updateProfile 编辑后本地刷新。
 */
export function useUserProfile(): UseUserProfileResult {
  const { status: authStatus } = useAuth();
  const isAuthenticated = authStatus === 'authenticated';
  const [profile, setProfile] = useState<UserProfile>(DEFAULT_USER_PROFILE);
  const [status, setStatus] = useState<RequestStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const fetchProfile = useCallback(async () => {
    if (!isAuthenticated) {
      // 未登录：用固定默认值，不请求云端，状态置 success 便于消费方直接渲染。
      setProfile(DEFAULT_USER_PROFILE);
      setStatus('success');
      setError(null);
      return;
    }
    setStatus('loading');
    setError(null);
    try {
      const res = await getUserProfile();
      if (!res.success || !res.data) {
        setError(res.message || '用户资料加载失败');
        setStatus('error');
        return;
      }
      setProfile(res.data);
      setStatus('success');
    } catch (err) {
      setError(err instanceof Error ? err.message : '用户资料加载失败');
      setStatus('error');
    }
  }, [isAuthenticated]);

  useEffect(() => {
    void fetchProfile();
  }, [fetchProfile]);

  const updateProfile = useCallback(
    async (payload: UpdateUserProfilePayload): Promise<string | null> => {
      if (!isAuthenticated) {
        return '未登录，无法保存资料';
      }
      setSaving(true);
      try {
        const res = await updateUserProfile(payload);
        if (!res.success || !res.data) {
          return res.message || '保存失败';
        }
        setProfile(res.data);
        return null;
      } catch (err) {
        return err instanceof Error ? err.message : '保存失败';
      } finally {
        setSaving(false);
      }
    },
    [isAuthenticated],
  );

  return { profile, isAuthenticated, status, error, saving, refetch: fetchProfile, updateProfile };
}
