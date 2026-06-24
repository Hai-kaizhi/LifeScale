import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_data.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_interceptor.dart';
import 'package:lifescale_mobile/core/providers.dart';
import 'package:lifescale_mobile/core/storage/app_paths.dart';
import 'package:lifescale_mobile/core/storage/database_service.dart';
import 'package:lifescale_mobile/core/storage/prefs_store.dart';
import 'package:lifescale_mobile/core/storage/secure_token_store.dart';
import 'package:lifescale_mobile/core/storage/vault_storage.dart';
import 'package:lifescale_mobile/features/auth/presentation/auth_controller.dart';
import 'package:lifescale_mobile/features/auth/presentation/auth_state.dart';
import 'package:lifescale_mobile/features/phase1/presentation/phase1_controller.dart';
import 'package:lifescale_mobile/features/phase1/presentation/phase1_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().close();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'login -> device -> changes -> file cache -> sync_state update',
    () async {
      final temp = await Directory.systemTemp.createTemp('lifescale_phase1_');
      await AppPaths.initForTest(temp.path);
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
        ..interceptors.add(MockApiInterceptor());

      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
          secureTokenStoreProvider.overrideWithValue(MemorySecureTokenStore()),
          dioProvider.overrideWithValue(dio),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async {
        await DatabaseService().close();
        await temp.delete(recursive: true);
      });

      await container
          .read(phase1ControllerProvider.notifier)
          .loginAndSync('lifescale', 'lifescale');

      final state = container.read(phase1ControllerProvider);
      expect(state.stage, Phase1Stage.ready);
      expect(state.preview, isNotNull);
      expect(state.preview!.model.focus, '完成产品方案初稿');
      expect(state.summary.cachedFiles, 2);
      expect(state.summary.failedFiles, 0);

      final cached = await VaultStorage.readVaultFile(MockApiData.todayPath);
      expect(cached, contains('## 今日复盘'));

      final rows = await DatabaseService().listSyncState();
      expect(
        rows.map((row) => row['vault_path']),
        contains(MockApiData.todayPath),
      );
      expect(
        rows.firstWhere(
          (row) => row['vault_path'] == MockApiData.todayPath,
        )['status'],
        'clean',
      );
    },
  );

  test('startup without token enters ready local mode', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lifescale_phase1_local_',
    );
    await AppPaths.initForTest(temp.path);
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
      ..interceptors.add(MockApiInterceptor());

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        secureTokenStoreProvider.overrideWithValue(MemorySecureTokenStore()),
        dioProvider.overrideWithValue(dio),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await DatabaseService().close();
      await temp.delete(recursive: true);
    });

    await container.read(phase1ControllerProvider.notifier).completeBoot();

    final state = container.read(phase1ControllerProvider);
    expect(state.bootComplete, isTrue);
    expect(state.stage, Phase1Stage.ready);
    expect(state.summary.offline, isTrue);
  });

  test('offline token validation keeps cached authenticated user', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lifescale_phase1_cached_auth_',
    );
    await AppPaths.initForTest(temp.path);
    final prefs = await SharedPreferences.getInstance();
    await PrefsStore(prefs).setUser(
      const UserSummary(id: 1, username: 'lifescale', email: 'local@test.dev'),
    );
    final tokenStore = MemorySecureTokenStore();
    await tokenStore.write('cached-token');
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
      ..interceptors.add(MockApiInterceptor(scenario: 'offline'));

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        secureTokenStoreProvider.overrideWithValue(tokenStore),
        dioProvider.overrideWithValue(dio),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await DatabaseService().close();
      await temp.delete(recursive: true);
    });

    container.read(authControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final auth = container.read(authControllerProvider);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.username, 'lifescale');
  });

  test('offline startup keeps cached Daily preview', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lifescale_phase1_offline_',
    );
    await AppPaths.initForTest(temp.path);
    await VaultStorage.writeVaultFile(
      MockApiData.todayPath,
      MockApiData.todayMarkdown,
    );
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
      ..interceptors.add(MockApiInterceptor(scenario: 'offline'));

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        secureTokenStoreProvider.overrideWithValue(MemorySecureTokenStore()),
        dioProvider.overrideWithValue(dio),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await DatabaseService().close();
      await temp.delete(recursive: true);
    });

    await container
        .read(phase1ControllerProvider.notifier)
        .loginAndSync('lifescale', 'lifescale');

    final state = container.read(phase1ControllerProvider);
    expect(state.stage, Phase1Stage.ready);
    expect(state.preview, isNotNull);
    expect(state.summary.offline, isTrue);
    expect(state.error, contains('最近缓存'));
  });
}
