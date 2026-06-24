import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/network/api_client.dart';
import 'package:lifescale_mobile/core/network/api_result.dart';
import 'package:lifescale_mobile/core/network/dto/auth_dtos.dart';
import 'package:lifescale_mobile/core/network/dto/vault_dtos.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_data.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_interceptor.dart';
import 'package:lifescale_mobile/core/storage/secure_token_store.dart';

void main() {
  ApiClient client(String scenario) {
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'));
    dio.interceptors.add(MockApiInterceptor(scenario: scenario));
    return ApiClient(dio: dio, tokenStore: MemorySecureTokenStore());
  }

  test(
    'mock auth/devices/changes/files use backend-shaped envelopes',
    () async {
      final api = client('normal');

      final login = await api.post<AuthSession>(
        '/auth/login',
        body: {'username': 'lifescale', 'password': 'lifescale'},
        fromJsonT: (json) => AuthSession.fromJson(json as Map<String, dynamic>),
      );
      expect(login, isA<ApiSuccess<AuthSession>>());

      final device = await api.post<DeviceDto>(
        '/auth/devices',
        body: {
          'deviceId': 'mobile-device-1',
          'name': 'LifeScale Mobile',
          'platform': 'android',
        },
        fromJsonT: (json) => DeviceDto.fromJson(json as Map<String, dynamic>),
      );
      expect(
        (device as ApiSuccess<DeviceDto>).data.deviceId,
        'mobile-device-1',
      );

      final devices = await api.get<List<DeviceDto>>(
        '/auth/devices',
        fromJsonT: (json) => (json as List)
            .map((item) => DeviceDto.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
      expect(
        (devices as ApiSuccess<List<DeviceDto>>).data.single.deviceId,
        'mobile-device-1',
      );

      final changes = await api.get<VaultChangesData>(
        '/vault/changes',
        fromJsonT: (json) =>
            VaultChangesData.fromJson(json as Map<String, dynamic>),
      );
      final changeData = (changes as ApiSuccess<VaultChangesData>).data;
      expect(changeData.changes, hasLength(2));
      expect(changeData.changes.first.vaultPath, MockApiData.todayPath);

      final file = await api.get<VaultFileData>(
        '/vault/files',
        query: {'path': MockApiData.todayPath},
        fromJsonT: (json) =>
            VaultFileData.fromJson(json as Map<String, dynamic>),
      );
      expect(
        (file as ApiSuccess<VaultFileData>).data.content,
        contains('## 今日重点'),
      );

      final push = await api.put<VaultPushResult>(
        '/vault/files',
        body: {
          'vaultPath': MockApiData.todayPath,
          'content': '${MockApiData.todayMarkdown}\n- mock saved',
          'ifMatchHash': file.data.contentHash,
          'deviceId': 'mobile-device-1',
        },
        fromJsonT: (json) =>
            VaultPushResult.fromJson(json as Map<String, dynamic>),
      );
      final pushData = (push as ApiSuccess<VaultPushResult>).data;
      expect(pushData.outcome, 'ok');
      expect(pushData.data!.content, contains('mock saved'));
    },
  );

  test(
    'mock failure scenarios cover no permission, empty and offline',
    () async {
      final denied = await client('no_permission').post<AuthSession>(
        '/auth/login',
        body: {'username': 'lifescale', 'password': 'lifescale'},
        fromJsonT: (json) => AuthSession.fromJson(json as Map<String, dynamic>),
      );
      expect(denied, isA<ApiFailure<AuthSession>>());
      expect((denied as ApiFailure<AuthSession>).code, 403);

      final empty = await client('empty').get<VaultChangesData>(
        '/vault/changes',
        fromJsonT: (json) =>
            VaultChangesData.fromJson(json as Map<String, dynamic>),
      );
      expect((empty as ApiSuccess<VaultChangesData>).data.changes, isEmpty);

      final offline = await client('offline').get<VaultChangesData>(
        '/vault/changes',
        fromJsonT: (json) =>
            VaultChangesData.fromJson(json as Map<String, dynamic>),
      );
      expect(offline, isA<ApiFailure<VaultChangesData>>());
    },
  );

  test('mock PUT files covers server error, offline and conflict', () async {
    final body = {
      'vaultPath': MockApiData.todayPath,
      'content': MockApiData.todayMarkdown,
      'deviceId': 'mobile-device-1',
    };

    final serverError = await client('server_error').put<VaultPushResult>(
      '/vault/files',
      body: body,
      fromJsonT: (json) =>
          VaultPushResult.fromJson(json as Map<String, dynamic>),
    );
    expect(serverError, isA<ApiFailure<VaultPushResult>>());

    final offline = await client('offline').put<VaultPushResult>(
      '/vault/files',
      body: body,
      fromJsonT: (json) =>
          VaultPushResult.fromJson(json as Map<String, dynamic>),
    );
    expect(offline, isA<ApiFailure<VaultPushResult>>());

    final conflict = await client('conflict').put<VaultPushResult>(
      '/vault/files',
      body: body,
      fromJsonT: (json) =>
          VaultPushResult.fromJson(json as Map<String, dynamic>),
    );
    final conflictData = (conflict as ApiSuccess<VaultPushResult>).data;
    expect(conflictData.outcome, 'conflict');
    expect(conflictData.conflict, isNotNull);
  });
}
