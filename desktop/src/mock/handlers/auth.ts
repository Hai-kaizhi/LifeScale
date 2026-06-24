import type { ApiResponse } from '../../shared/types/api';
import type { AuthSession, AuthUser } from '../../shared/types/auth';
import { mockInitProfileOnLogin } from './userProfile';

const MOCK_USER: AuthUser = { id: 1, username: 'mock', email: null };
const MOCK_TOKEN = 'mock.jwt.token';

export function mockLogin(username: string, _password: string): ApiResponse<AuthSession> {
  mockInitProfileOnLogin(username || 'mock');
  return {
    code: 200,
    success: true,
    message: 'ok',
    data: { userId: 1, username: username || 'mock', email: null, token: MOCK_TOKEN, expiresAt: null },
  };
}

export function mockRegister(username: string, _password: string, email?: string): ApiResponse<AuthSession> {
  mockInitProfileOnLogin(username || 'mock');
  return {
    code: 200,
    success: true,
    message: 'ok',
    data: { userId: 1, username: username || 'mock', email: email ?? null, token: MOCK_TOKEN, expiresAt: null },
  };
}

export function mockMe(): ApiResponse<AuthUser> {
  return { code: 200, success: true, message: 'ok', data: MOCK_USER };
}
