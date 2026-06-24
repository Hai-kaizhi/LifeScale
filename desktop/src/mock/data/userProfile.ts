import type { UserProfile } from '../../shared/types/userProfile';
import { DEFAULT_USER_PROFILE } from '../../shared/types/userProfile';

/**
 * mock 模式下内存态的个人资料：初始为默认资料（昵称留空，对应未登录/新注册），
 * 由 mockUpdateUserProfile 修改。保持与后端「注册时默认昵称=用户名」一致由 handler 注入。
 */
let mockProfile: UserProfile = { ...DEFAULT_USER_PROFILE };

export function getMockUserProfile(): UserProfile {
  return { ...mockProfile };
}

export function setMockUserProfile(next: UserProfile): void {
  mockProfile = { ...next };
}
