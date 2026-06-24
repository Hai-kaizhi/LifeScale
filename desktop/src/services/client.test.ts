import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ApiResponse } from '../shared/types/api';

function okResponse(): ApiResponse<{ ok: boolean }> {
  return {
    code: 200,
    success: true,
    message: 'ok',
    data: { ok: true },
  };
}

describe('api client offline-first behavior', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
    vi.resetModules();
  });

  async function loadRealClient() {
    vi.stubEnv('VITE_USE_MOCK', 'false');
    const runtime = await import('./runtimeMode');
    const client = await import('./client');
    return { ...runtime, ...client };
  }

  it('returns a failure envelope when fetch rejects', async () => {
    const { apiGet, setLocalMode } = await loadRealClient();
    setLocalMode(false);
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new TypeError('Failed to fetch')),
    );

    const res = await apiGet('/user/profile', okResponse);

    expect(res.success).toBe(false);
    expect(res.code).toBe(0);
    expect(res.message).toContain('Failed to fetch');
  });

  it('short-circuits non-auth requests in local mode', async () => {
    const { apiGet, setLocalMode } = await loadRealClient();
    const fetchSpy = vi.fn();
    setLocalMode(true);
    vi.stubGlobal('fetch', fetchSpy);

    const res = await apiGet('/vault/changes', okResponse);

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(res.success).toBe(false);
    expect(res.message).toContain('本地模式');
  });
});
