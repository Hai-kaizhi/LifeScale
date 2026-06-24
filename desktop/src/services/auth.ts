import { apiGet, apiPost } from './client';
import type { ApiResponse } from '../shared/types/api';
import type { AuthSession, AuthUser, DeviceDTO, DeviceRequest } from '../shared/types/auth';
import { mockLogin, mockMe, mockRegister } from '../mock/handlers/auth';

/** 登录换取 JWT。 */
export function login(username: string, password: string): Promise<ApiResponse<AuthSession>> {
  return apiPost<AuthSession>('/auth/login', { username, password }, () => mockLogin(username, password));
}

/** 注册并返回 JWT。 */
export function register(username: string, password: string, email?: string): Promise<ApiResponse<AuthSession>> {
  return apiPost<AuthSession>('/auth/register', { username, password, email }, () =>
    mockRegister(username, password, email),
  );
}

/** 校验当前 token 并取用户信息。 */
export function fetchMe(): Promise<ApiResponse<AuthUser>> {
  return apiGet<AuthUser>('/auth/me', () => mockMe());
}

/** 注册或更新当前设备，供多端同步状态解释使用。 */
export function upsertDevice(payload: DeviceRequest): Promise<ApiResponse<DeviceDTO>> {
  return apiPost<DeviceDTO>('/auth/devices', payload, () => ({
    code: 200,
    success: true,
    message: 'ok',
    data: {
      id: 1,
      deviceId: payload.deviceId,
      name: payload.name ?? '当前设备',
      platform: payload.platform ?? 'desktop',
      lastSeenAt: new Date().toISOString(),
      lastSyncedAt: null,
    },
  }));
}
