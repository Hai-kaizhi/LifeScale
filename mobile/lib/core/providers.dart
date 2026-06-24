import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'network/interceptors/auth_interceptor.dart';
import 'network/interceptors/dedup_interceptor.dart';
import 'network/interceptors/response_interceptor.dart';
import 'network/mock/mock_api_interceptor.dart';
import 'storage/database_service.dart';
import 'storage/lifescale_db_service.dart';
import 'storage/prefs_store.dart';
import 'storage/secure_token_store.dart';

/// JWT token 持久化（Keystore + 内存缓存）。
final secureTokenStoreProvider = Provider<SecureTokenStore>(
  (ref) => SecureTokenStore(),
);

/// 非敏感偏好。需在 main 中以 SharedPreferences 实例 override。
final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw UnimplementedError(
    'prefsStoreProvider 必须在 main 中用 SharedPreferences override',
  ),
);

/// 本地同步索引 DB（sync.db）。
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

/// 业务真相源 DB（lifescale.db，docs/09 §6.1，与 sync.db 物理分离）。
final lifescaleDbServiceProvider = Provider<LifescaleDbService>(
  (ref) => LifescaleDbService(),
);

/// Dio 单例 + 拦截器链。
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );
  if (AppConfig.useMockApi) {
    dio.interceptors.add(MockApiInterceptor(scenario: AppConfig.mockScenario));
  }
  dio.interceptors.add(AuthInterceptor(tokenStore));
  dio.interceptors.add(DedupInterceptor());
  dio.interceptors.add(ResponseInterceptor());
  assert(() {
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
    return true;
  }());
  return dio;
});

/// HTTP 客户端（封装信封解包）。
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    dio: ref.watch(dioProvider),
    tokenStore: ref.watch(secureTokenStoreProvider),
  ),
);
