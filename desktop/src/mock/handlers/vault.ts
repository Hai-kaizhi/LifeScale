import type { ApiResponse } from '../../shared/types/api';
import type {
  ConflictView,
  VaultChangeSummary,
  VaultChangesData,
  VaultFileData,
  VaultPushPayload,
  VaultPushResult,
  VaultVersionSummary,
} from '../../shared/types/vault';

/**
 * Vault 同步 mock：内存版「远端 vault」，模拟 created/ok/conflict 三态与墓碑，
 * 供无后端/无 Tauri 时联调同步引擎逻辑。（merged 三方合并已在后端实测，mock 不重复实现。）
 */
interface MockFile {
  content: string;
  hash: string;
  version: number;
  updatedAt: string;
  status: 'active' | 'deleted';
}
const files = new Map<string, MockFile>();
const versions = new Map<string, VaultVersionSummary[]>();

function now(): string {
  return new Date().toISOString();
}

/** 简单同步哈希（mock 自洽即可，不要求与真 SHA-256 一致）。 */
function mockHash(content: string): string {
  let h = 5381;
  for (let i = 0; i < content.length; i++) h = ((h << 5) + h + content.charCodeAt(i)) | 0;
  return 'mock_' + (h >>> 0).toString(16) + '_' + content.length;
}

function fileToData(path: string, f: MockFile): VaultFileData {
  return { vaultPath: path, content: f.content, contentHash: f.hash, version: f.version, serverMtime: f.updatedAt, size: f.content.length };
}

function bumpVersion(path: string, f: MockFile, deviceId: string | null) {
  f.version += 1;
  const list = versions.get(path) ?? [];
  list.unshift({ version: f.version, contentHash: f.hash, size: f.content.length, deviceId, createdAt: now() });
  versions.set(path, list);
}

export function mockGetVaultChanges(since?: string, _limit?: number): ApiResponse<VaultChangesData> {
  const sinceTs = since ? Date.parse(since) : 0;
  const changes: VaultChangeSummary[] = [];
  for (const [path, f] of files) {
    if (Date.parse(f.updatedAt) > sinceTs) {
      changes.push({ vaultPath: path, contentHash: f.hash, version: f.version, serverMtime: f.updatedAt, status: f.status, size: f.content.length });
    }
  }
  const serverTime = now();
  return { code: 200, success: true, message: 'ok', data: { changes, serverTime, nextCursor: serverTime, hasMore: false } };
}

export function mockGetVaultFile(vaultPath: string): ApiResponse<VaultFileData> {
  const f = files.get(vaultPath);
  if (!f || f.status === 'deleted') return { code: 404, success: false, message: '文件不存在或已删除', data: null as never };
  return { code: 200, success: true, message: 'ok', data: fileToData(vaultPath, f) };
}

export function mockPushVaultFile(payload: VaultPushPayload): ApiResponse<VaultPushResult> {
  const path = payload.vaultPath;
  const content = payload.content ?? '';
  const hash = mockHash(content);
  let f = files.get(path);
  if (!f || f.status === 'deleted') {
    const nf: MockFile = { content, hash, version: 1, updatedAt: now(), status: 'active' };
    files.set(path, nf);
    versions.set(path, [{ version: 1, contentHash: hash, size: content.length, deviceId: payload.deviceId ?? null, createdAt: now() }]);
    return { code: 200, success: true, message: 'ok', data: { outcome: 'created', data: fileToData(path, nf), conflict: null } };
  }
  if (payload.ifMatchHash && payload.ifMatchHash !== f.hash) {
    // 冲突：服务端保留 theirs，返回冲突视图
    const conflict: ConflictView = {
      baseHash: payload.ifMatchHash,
      theirsHash: f.hash,
      theirsContent: f.content,
      conflictCopyPath: path.replace(/\.md$/i, '') + '.conflict-mock.md',
      conflictId: Math.floor(Math.random() * 1e9),
    };
    return { code: 200, success: true, message: 'ok', data: { outcome: 'conflict', data: null, conflict } };
  }
  f.content = content;
  f.hash = hash;
  f.updatedAt = now();
  f.status = 'active';
  bumpVersion(path, f, payload.deviceId ?? null);
  return { code: 200, success: true, message: 'ok', data: { outcome: 'ok', data: fileToData(path, f), conflict: null } };
}

export function mockDeleteVaultFile(vaultPath: string, _deviceId?: string): ApiResponse<void> {
  const f = files.get(vaultPath);
  if (!f) return { code: 404, success: false, message: '文件不存在', data: null as never };
  f.status = 'deleted';
  f.updatedAt = now();
  return { code: 200, success: true, message: 'ok', data: undefined as never };
}

export function mockGetVaultVersions(vaultPath: string, _limit?: number): ApiResponse<VaultVersionSummary[]> {
  return { code: 200, success: true, message: 'ok', data: versions.get(vaultPath) ?? [] };
}
