/// 后端 API 路径常量（基址 `AppConfig.apiBaseUrl` 已含 `/api`）。
///
/// 移动端核心今日内容（重点/日程/快速记录/复盘）与笔记均以 **Daily Markdown / Vault
/// Markdown** 为单一事实来源，统一走 `/api/vault/*` 同步（doc05 §14.4）。不再使用
/// Model B 旧 REST（/api/schedules、/api/quick-notes、/api/date-entity、/api/daily-reviews）。
abstract final class ApiEndpoints {
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authMe = '/auth/me';
  static const String authDevices = '/auth/devices';

  static const String vaultChanges = '/vault/changes';
  static const String vaultFiles = '/vault/files';
  static const String vaultFilesVersions = '/vault/files/versions';
  static const String vaultHeartbeat = '/vault/heartbeat';
  static const String vaultAttachments = '/vault/attachments';

  /// 当天实体同步（docs/09 §9.3，P4）：当天未沉淀实体跨设备 LWW 同步。
  static const String vaultDailyEntities = '/vault/daily-entities';
  static const String vaultDailyEntityChanges = '/vault/daily-entities/changes';

  /// 阶段九：冲突列表与解决。
  static const String vaultConflicts = '/vault/conflicts';

  /// 解决单个冲突：`/vault/conflicts/{id}/resolve`。
  static String resolveConflict(int id) => '/vault/conflicts/$id/resolve';

  /// 单个附件下载：`/vault/attachments/{hash}`（返回裸字节流，非 ApiResponse 信封）。
  static String attachment(String hash) => '/vault/attachments/$hash';
}
