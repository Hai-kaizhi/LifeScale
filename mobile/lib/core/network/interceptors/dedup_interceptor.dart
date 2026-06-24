import 'package:dio/dio.dart';

/// PUT 去重拦截器（镜像桌面端 `client.ts#apiPutDedup` 的 lead-with-last 去重）。
///
/// 对标记了 `options.extra['dedup'] = true` 的请求，按 `method:path` 维护在途
/// CancelToken：同 key 新请求会取消上一个未完成请求，只保留最新。被取消的请求
/// 在 ApiClient 中映射为 `ApiFailure(0, 'cancelled')`，调用方据此跳过 error 态。
///
/// Step 0 暂不触发（保存类推送属阶段三）；先就位以备后续。
class DedupInterceptor extends Interceptor {
  final Map<String, CancelToken> _inflight = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['dedup'] != true) {
      handler.next(options);
      return;
    }
    final key = '${options.method}:${options.path}';
    final existing = _inflight[key];
    if (existing != null && !existing.isCancelled) {
      existing.cancel('superseded');
    }
    final token = CancelToken();
    options.cancelToken = token;
    _inflight[key] = token;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _cleanup(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _cleanup(err.requestOptions);
    handler.next(err);
  }

  void _cleanup(RequestOptions options) {
    if (options.extra['dedup'] != true) return;
    final key = '${options.method}:${options.path}';
    if (_inflight[key] == options.cancelToken) {
      _inflight.remove(key);
    }
  }
}
