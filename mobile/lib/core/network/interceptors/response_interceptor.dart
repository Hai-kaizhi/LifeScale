import 'package:dio/dio.dart';

import '../auth_bus.dart';

/// 响应错误拦截器：检测后端 `JwtAuthFilter` 写出的 HTTP 401。
///
/// 对非 `/auth/*` 接口的 401 通过 [AuthBus] 派发失效事件，由 AuthController 订阅后
/// 回到 local 态并清 token；随后仍把错误继续抛出，交由 ApiClient 映射为 ApiFailure。
class ResponseInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    if (status == 401 && !path.startsWith('/auth/')) {
      AuthBus.instance.expired();
    }
    handler.next(err);
  }
}
