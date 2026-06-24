import type { ApiResponse } from '../../shared/types/api';
import type { UpdateUserProfilePayload } from '../../shared/types/userProfile';
import type { UserProfile } from '../../shared/types/userProfile';
import { getMockUserProfile, setMockUserProfile } from '../data/userProfile';

export function mockGetUserProfile(): ApiResponse<UserProfile> {
  return { code: 200, success: true, message: 'ok', data: getMockUserProfile() };
}

export function mockUpdateUserProfile(payload: UpdateUserProfilePayload): ApiResponse<UserProfile> {
  const current = getMockUserProfile();
  const next: UserProfile = {
    nickname: payload.nickname !== undefined ? payload.nickname : current.nickname,
    avatarUrl:
      payload.avatarUrl !== undefined ? payload.avatarUrl : current.avatarUrl,
    greeting: payload.greeting !== undefined ? payload.greeting : current.greeting,
    motivationalQuote:
      payload.motivationalQuote !== undefined ? payload.motivationalQuote : current.motivationalQuote,
  };
  setMockUserProfile(next);
  return { code: 200, success: true, message: 'ok', data: next };
}

/** mock 模式登录/注册成功后初始化昵称为用户名，模拟后端「注册即初始化默认资料」。 */
export function mockInitProfileOnLogin(username: string): void {
  const current = getMockUserProfile();
  if (!current.nickname) {
    setMockUserProfile({ ...current, nickname: username });
  }
}
