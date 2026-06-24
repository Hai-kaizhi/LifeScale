/**
 * 运行态标记（与鉴权状态联动）：
 * - `local`（未登录）：纯本地，不请求云端。client.ts 据此短路非鉴权 `/api` 调用；
 *   VaultSyncEngine 据此关闭云同步 push/pull。
 * - 非 local（已登录）：恢复云端请求与同步。
 *
 * 由 `useAuth` 在鉴权状态切换时调用 `setLocalMode`。client.ts 与 VaultSyncProvider 读取。
 */
let localMode = false;

export function setLocalMode(enabled: boolean): void {
  localMode = enabled;
}

export function isLocalMode(): boolean {
  return localMode;
}
