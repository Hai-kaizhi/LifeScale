import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response.freezed.dart';
part 'api_response.g.dart';

/// 后端统一响应信封，与 `backend/.../common/model/ApiResponse.java` 对齐。
/// 后端 `@JsonInclude(ALWAYS)`：四字段恒在（即便 data=null）。
///
/// 泛型 `T` 经 `genericArgumentFactories` 由调用方提供 `fromJsonT`。
@Freezed(genericArgumentFactories: true)
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse({
    required int code,
    required bool success,
    required String message,
    T? data,
  }) = _ApiResponse<T>;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$ApiResponseFromJson<T>(json, fromJsonT);
}
