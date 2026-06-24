import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/network/api_client.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_data.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_interceptor.dart';
import 'package:lifescale_mobile/core/providers.dart';
import 'package:lifescale_mobile/core/storage/app_paths.dart';
import 'package:lifescale_mobile/core/storage/database_service.dart';
import 'package:lifescale_mobile/core/storage/lifescale_db_service.dart';
import 'package:lifescale_mobile/core/storage/prefs_store.dart';
import 'package:lifescale_mobile/core/storage/secure_token_store.dart';
import 'package:lifescale_mobile/core/util/date_util.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_mutation_service.dart';
import 'package:lifescale_mobile/features/today/data/today_repository.dart';
import 'package:lifescale_mobile/features/today/domain/today_models.dart';
import 'package:lifescale_mobile/features/today/presentation/today_controller.dart';
import 'package:lifescale_mobile/features/vault/data/vault_api.dart';
import 'package:lifescale_mobile/features/vault/data/vault_repository.dart';
import 'package:lifescale_mobile/shared/constants/markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 今日仓库测试（阶段三/四，数据源为 Daily Markdown / Vault Markdown）。
///
/// 通过 MockApiInterceptor 的 `/vault/files` 读取今天的 Daily Markdown 种子，
/// 验证加载、快速记录写入、任务增删改、重点标记均落到同一份 Daily 文件。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().close();
    SharedPreferences.setMockInitialValues({});
  });

  test('normal scenario loads today schedules, notes, focus and review from Daily MD',
      () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);

    final result = await h.repository.loadToday(MockApiData.todayDate);

    expect(result.status, TodayLoadStatus.ready);
    // todayMarkdown 种子：6 个任务 + 4 个时间记录 + 2 条快速记录 + 4 题复盘。
    expect(result.data!.focus, '完成产品方案初稿');
    expect(result.data!.taskCount, 6);
    expect(result.data!.quickNotes, hasLength(2));
    expect(result.data!.reviewAnsweredCount, 4);
  });

  test('empty scenario returns empty state (no Daily)', () async {
    final h = await _Harness.create('empty');
    addTearDown(h.dispose);

    final result = await h.repository.loadToday(MockApiData.todayDate);

    // empty 态：今天的 Daily 文件不存在（404）→ empty。
    expect(result.status, TodayLoadStatus.empty);
  });

  test('add quick note appends to Daily markdown and keeps existing notes',
      () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(MockApiData.todayDate)).data!;

    final result = await h.repository.addQuickNote(
      MockApiData.todayDate,
      '路上想到一个入口',
      previous: base,
    );

    expect(result.data.quickNotes, hasLength(base.quickNotes.length + 1));
    expect(result.data.quickNotes.last.content, '路上想到一个入口');
    expect(result.syncStatus, TodaySyncStatus.clean);
  });

  test('toggle task flips completion by schedule id', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(MockApiData.todayDate)).data!;
    // 种子中 s5（阅读 30 分钟）为未完成任务。
    final s5 = base.tasks.firstWhere((t) => t.id == 's5');
    expect(s5.completed, isFalse);

    final result = await h.repository.toggleTask(
      MockApiData.todayDate,
      's5',
      true,
      previous: base,
    );

    expect(
      result.data.tasks.firstWhere((t) => t.id == 's5').completed,
      isTrue,
    );
    expect(result.data.taskCount, base.taskCount);
  });

  test('create, update, delete task mutate the Daily schedule section',
      () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(MockApiData.todayDate)).data!;

    final created = await h.repository.createTask(
      MockApiData.todayDate,
      const TodayTaskDraft(
        title: '补齐移动端交互',
        startTime: '20:00',
        endTime: '21:00',
        category: ScheduleCategory.work,
      ),
      previous: base,
    );
    final taskId = created.data.tasks.last.id;
    expect(created.data.tasks.last.title, '补齐移动端交互');

    final updated = await h.repository.updateTask(
      MockApiData.todayDate,
      taskId,
      const TodayTaskDraft(
        title: '补齐移动端任务交互',
        startTime: '20:30',
        endTime: '21:10',
        category: ScheduleCategory.life,
      ),
      previous: created.data,
    );
    final updatedTask = updated.data.tasks.firstWhere((t) => t.id == taskId);
    expect(updatedTask.title, '补齐移动端任务交互');
    expect(updatedTask.category, ScheduleCategory.life);

    final deleted = await h.repository.deleteTask(
      MockApiData.todayDate,
      taskId,
      previous: updated.data,
    );
    expect(
      deleted.data.tasks.where((t) => t.id == taskId).toList(),
      isEmpty,
    );
  });

  test('toggle focus marks a schedule as focus', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(MockApiData.todayDate)).data!;

    final result = await h.repository.toggleFocus(
      MockApiData.todayDate,
      's2',
      previous: base,
    );

    expect(
      result.data.schedules.firstWhere((s) => s.id == 's2').focus,
      isTrue,
    );
  });

  test('controller exposes ready state and read-only feedback', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final container = h.container();
    addTearDown(container.dispose);

    await container.read(todayControllerProvider.notifier).loadToday();
    final state = container.read(todayControllerProvider);

    expect(state.status, TodayLoadStatus.ready);
    expect(state.data!.reviewAnsweredCount, 4);

    container.read(todayControllerProvider.notifier).showDisabled('任务勾选');
    expect(container.read(todayControllerProvider).message, contains('不可用'));
  });

  test('controller add quick note writes through and syncs clean', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final container = h.container();
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);

    await controller.loadToday();
    final ok = await controller.addQuickNote('控制器新增记录');
    expect(ok, isTrue);
    final state = container.read(todayControllerProvider);
    expect(state.submitting, isFalse);
    expect(state.syncStatus, TodaySyncStatus.clean);
    expect(state.data!.quickNotes.last.content, '控制器新增记录');
  });

  test('controller allows editing on historical date (全面放开只读)', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final container = h.container();
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);

    await controller.loadToday();
    await controller.changeDate(
      DateUtil.plusDays(MockApiData.todayDate, -1)!,
    );
    // 放开只读后：历史日期也能写入快速记录。
    final ok = await controller.addQuickNote('历史日期也能记录');
    expect(ok, isTrue);
    final state = container.read(todayControllerProvider);
    expect(state.data!.quickNotes.last.content, '历史日期也能记录');
  });
}

class _Harness {
  const _Harness({
    required this.temp,
    required this.dio,
    required this.prefs,
    required this.repository,
  });

  final Directory temp;
  final Dio dio;
  final PrefsStore prefs;
  final TodayRepository repository;

  static Future<_Harness> create(String scenario) async {
    final temp = await Directory.systemTemp.createTemp('lifescale_today_');
    await AppPaths.initForTest(temp.path);
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PrefsStore(sharedPrefs);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
      ..interceptors.add(MockApiInterceptor(scenario: scenario));
    final client = ApiClient(dio: dio, tokenStore: MemorySecureTokenStore());
    final vaultApi = VaultApi(client);
    final db = DatabaseService();
    final vaultRepo = VaultRepository(vaultApi, db, prefs);
    final lsDb = LifescaleDbService();
    await lsDb.get();
    final mutation = DailyMutationService(vaultRepo, lsDb);
    return _Harness(
      temp: temp,
      dio: dio,
      prefs: prefs,
      repository: TodayRepository(mutation),
    );
  }

  ProviderContainer container() => ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(MemorySecureTokenStore()),
          dioProvider.overrideWithValue(dio),
        ],
      );

  Future<void> dispose() async {
    await DatabaseService().close();
    await temp.delete(recursive: true);
  }
}
