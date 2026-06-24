/// 编译期配置：通过 `--dart-define` 注入，避免敏感/环境相关常量入仓。
///
/// - 模拟器默认 `http://10.0.2.2:8080/api`（10.0.2.2 映射到宿主机回环）。
/// - 真机由运行脚本自动探测宿主机 LAN IP，注入
///   `--dart-define=LIFESCALE_API_BASE_URL=http://<LAN-IP>:8080/api`。
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'LIFESCALE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  /// 是否为模拟器目标（仅用于 StatusLine 展示，不影响行为）。
  static const bool isEmulator = bool.fromEnvironment(
    'LIFESCALE_IS_EMULATOR',
    defaultValue: true,
  );

  /// Phase 1 frontend runs mock-first until the real backend/database path is
  /// declared ready. Set to false with --dart-define to exercise real APIs.
  static const bool useMockApi = bool.fromEnvironment(
    'LIFESCALE_USE_MOCK_API',
    defaultValue: true,
  );

  /// Optional mock scenario switch used by tests/manual QA.
  ///
  /// Supported values: normal, login_fail, no_permission, empty, offline,
  /// partial_fail, server_error, conflict.
  static const String mockScenario = String.fromEnvironment(
    'LIFESCALE_MOCK_SCENARIO',
    defaultValue: 'normal',
  );
}
