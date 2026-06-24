import 'package:dio/dio.dart';

import '../../storage/secure_token_store.dart';

/// 鉴权拦截器：注入 `Authorization: Bearer <jwt>`；并对「未登录 + 非鉴权接口」短路。
///
/// 短路语义镜像桌面端 `client.ts#shouldShortCircuitLocal`：本地态下非 `/auth/*`
/// 调用直接返回空响应（code=0），既不发网络请求，也不触发 401 登出循环。
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore);

  final SecureTokenStore _tokenStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (!_tokenStore.hasToken && !path.startsWith('/auth/')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'code': 0,
            'success': false,
            'message': '本地模式：未登录，未请求云端',
            'data': null,
          },
        ),
      );
      return;
    }
    if (_tokenStore.hasToken) {
      options.headers['Authorization'] = 'Bearer ${_tokenStore.token}';
    }
    handler.next(options);
  }
}
