import { USE_MOCK } from '../mock';
import { API_BASE_URL } from './apiConfig';
import { AUTH_EXPIRED_EVENT, clearAuth, getToken } from './authToken';
import { isLocalMode } from './runtimeMode';
import type { ApiResponse } from '../shared/types/api';

type MockResolver<T> = () => ApiResponse<T>;

function mockDelay(): Promise<void> {
  return new Promise((r) => setTimeout(r, 200 + Math.random() * 200));
}

/**
 * 本地模式（未登录）下，对非鉴权 `/api` 调用统一返回空响应，既不发网络请求、也不触发 401 登出循环。
 * `/auth/*` 放行（登录注册需真正命中后端）。
 */
const LOCAL_EMPTY_RESPONSE = {
  code: 0,
  success: false,
  message: '本地模式：未登录，未请求云端',
  data: null,
} as const;

function failureResponse<T>(message: string, code = 0): ApiResponse<T> {
  return {
    code,
    success: false,
    message,
    data: null as T,
  };
}

/** 本地态且非鉴权接口 → 短路为空响应（不发请求）。 */
function shouldShortCircuitLocal(path: string): boolean {
  return isLocalMode() && !path.startsWith('/auth/');
}

/** 注入 Authorization Bearer（若有 token）。 */
function authHeaders(): Record<string, string> {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/** 解析响应；遇 401（且非鉴权接口）清除 token 并派发失效事件，由 AuthProvider 登出。 */
async function parse<T>(res: Response, path: string): Promise<ApiResponse<T>> {
  if (res.status === 401 && !path.startsWith('/auth/')) {
    clearAuth();
    window.dispatchEvent(new CustomEvent(AUTH_EXPIRED_EVENT));
  }
  let json: ApiResponse<T>;
  try {
    json = (await res.json()) as ApiResponse<T>;
  } catch {
    return failureResponse<T>(res.ok ? '响应解析失败' : `请求失败（HTTP ${res.status}）`, res.status);
  }
  return json;
}

async function safeFetch<T>(path: string, init?: RequestInit): Promise<ApiResponse<T>> {
  try {
    const res = await fetch(`${API_BASE_URL}${path}`, init);
    return parse<T>(res, path);
  } catch (err) {
    return failureResponse<T>(err instanceof Error ? err.message : '网络不可用');
  }
}

export async function apiGet<T>(path: string, mockFn: MockResolver<T>): Promise<ApiResponse<T>> {
  if (USE_MOCK) {
    await mockDelay();
    return mockFn();
  }
  if (shouldShortCircuitLocal(path)) {
    return LOCAL_EMPTY_RESPONSE as ApiResponse<T>;
  }
  return safeFetch<T>(path, { headers: { ...authHeaders() } });
}

export async function apiPut<T>(path: string, body: unknown, mockFn: MockResolver<T>): Promise<ApiResponse<T>> {
  if (USE_MOCK) {
    await mockDelay();
    return mockFn();
  }
  if (shouldShortCircuitLocal(path)) {
    return LOCAL_EMPTY_RESPONSE as ApiResponse<T>;
  }
  return safeFetch<T>(path, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  });
}

// 同 path 的进行中 PUT 请求（lead-with-last 去重）
const inflightPuts = new Map<string, { controller: AbortController; promise: Promise<ApiResponse<unknown>> }>();

/**
 * 去重 PUT：同 path 上一个未完成请求会被 abort 取消，只保留最新一个真正完成。
 * 被取消的请求返回 code=0 的 cancelled 响应，调用方据此跳过 error 态。
 * 适用于保存类接口（内容保存），避免快速保存堆积请求。GET 不适用。
 */
export async function apiPutDedup<T>(path: string, body: unknown, mockFn: MockResolver<T>): Promise<ApiResponse<T>> {
  if (USE_MOCK) {
    await mockDelay();
    return mockFn();
  }
  if (shouldShortCircuitLocal(path)) {
    return LOCAL_EMPTY_RESPONSE as ApiResponse<T>;
  }
  const existing = inflightPuts.get(path);
  if (existing) {
    existing.controller.abort();
  }
  const controller = new AbortController();
  const promise = fetch(`${API_BASE_URL}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
    signal: controller.signal,
  })
    .then((res) => parse<T>(res, path))
    .catch((err: unknown) => {
      if (err instanceof DOMException && err.name === 'AbortError') {
        return { code: 0, success: false, message: 'cancelled', data: null } as ApiResponse<T>;
      }
      return failureResponse<T>(err instanceof Error ? err.message : '网络不可用');
    })
    .finally(() => {
      if (inflightPuts.get(path)?.controller === controller) {
        inflightPuts.delete(path);
      }
    });
  inflightPuts.set(path, { controller, promise: promise as Promise<ApiResponse<unknown>> });
  return promise;
}

export async function apiPost<T>(path: string, body: unknown, mockFn: MockResolver<T>): Promise<ApiResponse<T>> {
  if (USE_MOCK) {
    await mockDelay();
    return mockFn();
  }
  if (shouldShortCircuitLocal(path)) {
    return LOCAL_EMPTY_RESPONSE as ApiResponse<T>;
  }
  return safeFetch<T>(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  });
}

export async function apiDelete<T>(path: string, mockFn: MockResolver<T>, body?: unknown): Promise<ApiResponse<T>> {
  if (USE_MOCK) {
    await mockDelay();
    return mockFn();
  }
  if (shouldShortCircuitLocal(path)) {
    return LOCAL_EMPTY_RESPONSE as ApiResponse<T>;
  }
  return safeFetch<T>(path, {
    method: 'DELETE',
    headers: body ? { 'Content-Type': 'application/json', ...authHeaders() } : { ...authHeaders() },
    body: body ? JSON.stringify(body) : undefined,
  });
}

/**
 * 附件上传（multipart）：仅由同步引擎在已登录+联网时调用，不走 USE_MOCK/本地短路。
 * 返回 JSON ApiResponse（含 hash/size/path）。
 */
export async function apiUploadAttachment<T>(
  path: string,
  bytes: Uint8Array,
  filename = 'attachment',
): Promise<ApiResponse<T>> {
  const form = new FormData();
  // Blob 自带 type；服务端 MultipartFile 接收。
  const blob = new Blob([bytes], { type: 'application/octet-stream' });
  form.append('file', blob, filename);
  return safeFetch<T>(path, {
    method: 'POST',
    headers: { ...authHeaders() },
    body: form,
  });
}

/**
 * 附件下载（二进制流）：返回 ArrayBuffer；缺失/失败返回 null。401（非鉴权接口）触发登出。
 */
export async function apiGetBytes(path: string): Promise<ArrayBuffer | null> {
  try {
    const res = await fetch(`${API_BASE_URL}${path}`, { headers: { ...authHeaders() } });
    if (res.status === 401 && !path.startsWith('/auth/')) {
      clearAuth();
      window.dispatchEvent(new CustomEvent(AUTH_EXPIRED_EVENT));
      return null;
    }
    if (!res.ok) return null;
    return res.arrayBuffer();
  } catch {
    return null;
  }
}
