import { apiDelete, apiGet, apiGetBytes, apiPutDedup, apiUploadAttachment } from '../client';
import type { ApiResponse } from '../../shared/types/api';
import type {
  AttachmentUploadResult,
  ConflictView,
  VaultChangeSummary,
  VaultChangesData,
  VaultFileData,
  VaultPushPayload,
  VaultPushResult,
  VaultVersionSummary,
} from '../../shared/types/vault';
import {
  mockDeleteVaultFile,
  mockGetVaultChanges,
  mockGetVaultFile,
  mockGetVaultVersions,
  mockPushVaultFile,
} from '../../mock/handlers/vault';

const ENC = encodeURIComponent;

/** 增量变更摘要（按 updated_at 游标，含墓碑）。 */
export function getVaultChanges(since?: string, limit?: number): Promise<ApiResponse<VaultChangesData>> {
  const search = new URLSearchParams();
  if (since) search.set('since', since);
  if (limit) search.set('limit', String(limit));
  const q = search.toString();
  return apiGet<VaultChangesData>(`/vault/changes${q ? `?${q}` : ''}`, () => mockGetVaultChanges(since, limit));
}

/** 拉取单文件正文 + hash + version。 */
export function getVaultFile(vaultPath: string): Promise<ApiResponse<VaultFileData>> {
  return apiGet<VaultFileData>(`/vault/files?path=${ENC(vaultPath)}`, () => mockGetVaultFile(vaultPath));
}

/** 推送文件（乐观锁 + 三方合并）。同 path 进行中的 PUT 以最新为准（去重）。 */
export function pushVaultFile(payload: VaultPushPayload): Promise<ApiResponse<VaultPushResult>> {
  return apiPutDedup<VPushResultOrConflict>(
    `/vault/files?_=${ENC(payload.vaultPath)}`,
    payload,
    () => mockPushVaultFile(payload),
  ) as Promise<ApiResponse<VaultPushResult>>;
}

/** 删除文件（墓碑）。 */
export function deleteVaultFile(vaultPath: string, deviceId?: string): Promise<ApiResponse<void>> {
  const search = new URLSearchParams({ path: vaultPath });
  if (deviceId) search.set('deviceId', deviceId);
  return apiDelete<void>(`/vault/files?${search.toString()}`, () => mockDeleteVaultFile(vaultPath, deviceId));
}

/** 版本历史摘要。 */
export function getVaultVersions(vaultPath: string, limit = 20): Promise<ApiResponse<VaultVersionSummary[]>> {
  return apiGet<VaultVersionSummary[]>(
    `/vault/files/versions?path=${ENC(vaultPath)}&limit=${limit}`,
    () => mockGetVaultVersions(vaultPath, limit),
  );
}

/** 上传附件（按内容 hash 去重）。仅在已登录+联网时由引擎调用。 */
export function uploadAttachment(bytes: Uint8Array): Promise<ApiResponse<AttachmentUploadResult>> {
  return apiUploadAttachment<AttachmentUploadResult>('/vault/attachments', bytes);
}

/** 按 hash 下载附件字节；缺失/失败返回 null。 */
export async function downloadAttachment(hash: string): Promise<Uint8Array | null> {
  const buf = await apiGetBytes(`/vault/attachments/${ENC(hash)}`);
  return buf ? new Uint8Array(buf) : null;
}

// 仅用于让 apiPutDedup 的泛型收敛为「成功体或冲突体」
type VPushResultOrConflict = VaultPushResult | ConflictView | VaultChangeSummary;
