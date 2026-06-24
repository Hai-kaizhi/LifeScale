import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'api_result.dart';
import 'dto/api_response.dart';
import 'dto/vault_dtos.dart';

/// HTTP 客户端封装：统一把 `ApiResponse<T>` 信封解包为 [ApiResult<T>]，
/// 并处理网络错误 / 取消 / 401 副作用（副作用在 [ResponseInterceptor] 内完成）。
class ApiClient {
  ApiClient({required this.dio, required this.tokenStore});

  final Dio dio;
  final SecureTokenStore tokenStore;

  Future<ApiResult<T>> get<T>(
    String path, {
    required T Function(Object?) fromJsonT,
    Map<String, dynamic>? query,
  }) => _request<T>('GET', path, query: query, fromJsonT: fromJsonT);

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    required T Function(Object?) fromJsonT,
    Map<String, dynamic>? query,
    bool dedup = false,
  }) => _request<T>(
    'POST',
    path,
    body: body,
    query: query,
    fromJsonT: fromJsonT,
    dedup: dedup,
  );

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    required T Function(Object?) fromJsonT,
    bool dedup = false,
  }) =>
      _request<T>('PUT', path, body: body, fromJsonT: fromJsonT, dedup: dedup);

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? body,
    required T Function(Object?) fromJsonT,
    Map<String, dynamic>? query,
  }) => _request<T>(
    'DELETE',
    path,
    body: body,
    query: query,
    fromJsonT: fromJsonT,
  );

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object?) fromJsonT,
    bool dedup = false,
  }) async {
    try {
      final res = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: dedup ? const {'dedup': true} : null,
        ),
      );
      return _parse<T>(res, fromJsonT);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return ApiFailure<T>(0, 'cancelled');
      }
      return _failureFromError<T>(e);
    }
  }

  ApiResult<T> _parse<T>(Response<dynamic> res, T Function(Object?) fromJsonT) {
    final body = res.data;
    if (body is Map<String, dynamic>) {
      try {
        final api = ApiResponse.fromJson(body, fromJsonT);
        if (api.success) {
          final data = api.data;
          if (data == null) {
            return ApiFailure<T>(-1, '响应数据为空');
          }
          return ApiSuccess<T>(data);
        }
        return ApiFailure<T>(api.code, api.message);
      } catch (e) {
        return ApiFailure<T>(-1, '响应解析失败：$e');
      }
    }
    return ApiFailure<T>(-1, '响应格式异常');
  }

  ApiFailure<T> _failureFromError<T>(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code'];
      final msg = data['message'];
      return ApiFailure<T>(
        code is int ? code : -1,
        msg is String ? msg : '请求失败',
      );
    }
    return ApiFailure<T>(-1, e.message ?? '网络错误');
  }

  /// 附件上传（multipart）。不走本地短路（与桌面一致）。
  Future<ApiResult<AttachmentUploadResult>> uploadAttachment(
    String path,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await dio.post<dynamic>(path, data: form);
      return _parse<AttachmentUploadResult>(
        res,
        (j) => AttachmentUploadResult.fromJson(j as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return ApiFailure<AttachmentUploadResult>(0, 'cancelled');
      }
      return _failureFromError<AttachmentUploadResult>(e);
    }
  }

  /// 附件下载（裸字节流，非 ApiResponse）。缺失/失败返回 null。
  Future<Uint8List?> downloadBytes(String path) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException {
      return null;
    }
  }

  /// 便于 push/pull 复用的 VaultFileData 解析器。
  static VaultFileData parseVaultFile(Object? json) =>
      VaultFileData.fromJson(json as Map<String, dynamic>);
}
