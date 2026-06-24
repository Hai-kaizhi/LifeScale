/// 统一 API 调用结果：成功带数据，失败带 code/message。
///
/// 拦截器侧的副作用（401 清 token + 回 local 模式）由 `ResponseInterceptor` 处理，
/// 业务层只通过 `ApiResult` 模式匹配消费。
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final int code;
  final String message;
  const ApiFailure(this.code, this.message);
}
