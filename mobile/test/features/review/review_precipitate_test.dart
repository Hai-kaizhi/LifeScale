import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/network/api_client.dart';
import 'package:lifescale_mobile/core/network/mock/mock_api_interceptor.dart';
import 'package:lifescale_mobile/core/storage/app_paths.dart';
import 'package:lifescale_mobile/core/storage/database_service.dart';
import 'package:lifescale_mobile/core/storage/lifescale_db_service.dart';
import 'package:lifescale_mobile/core/storage/prefs_store.dart';
import 'package:lifescale_mobile/core/storage/secure_token_store.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_entities.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_mutation_service.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/daily_doc.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/quick_note.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/schedule.dart';
import 'package:lifescale_mobile/features/review/data/review_precipitate_service.dart';
import 'package:lifescale_mobile/features/vault/data/vault_api.dart';
import 'package:lifescale_mobile/features/vault/data/vault_repository.dart';
import 'package:lifescale_mobile/shared/constants/markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 沉淀服务测试（docs/09 §7.2）：验证 settleDay 从 SQL 实体生成干净 Notes/Daily/ .md
/// + 写 ls_daily_settlement + mark settled。适配 P6 SQL-first 重写。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().close();
    await LifescaleDbService().close();
    SharedPreferences.setMockInitialValues({});
  });

  test('settleDay 空数据 → empty（不写 .md）', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    final result = await h.service.settleDay('2099-01-01');
    expect(result.status, SettlementStatus.empty);
    expect(result.mdVaultPath, isNull);
  });

  test('settleDay 有数据 → settled：生成干净 Notes/Daily/ .md + settlement 记录 + mark settled',
      () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    // seed 当天 SQL 实体（走 daily_entities batchReplace）。
    const date = '2026-06-23';
    await batchReplaceSchedules(h.lsDb, date, [
      Schedule(
        id: 'sch-1',
        title: '同步联调',
        completed: false,
        category: ScheduleCategory.work,
        categoryColor: ScheduleCategory.work.color,
        type: ScheduleType.task,
        startTime: '09:00',
        endTime: '10:00',
        date: date,
        sortOrder: 0,
      ),
    ]);
    await batchReplaceReviews(h.lsDb, date, [
      const ReviewEntry(questionId: 'q1', title: '今天完成了什么', content: '写完文档'),
    ]);

    final result = await h.service.settleDay(date);
    expect(result.status, SettlementStatus.settled);
    expect(result.mdVaultPath, settlementVaultPath(date));
    expect(result.mdContentHash, isNotEmpty);
    expect(result.overwritten, isFalse);

    // 本地沙盒已写入 Notes/Daily/<date>.md（零注释）。
    final md = await File('${AppPaths.appDocs}/${result.mdVaultPath}').readAsString();
    expect(md.contains('<!--'), isFalse);
    expect(md.contains('## 今日日程'), isTrue);
    expect(md.contains('同步联调'), isTrue);
    expect(md.contains('今天完成了什么'), isTrue);

    // settlement 记录已存。
    final settlement = await h.lsDb.getSettlement(date);
    expect(settlement, isNotNull);
    expect(settlement!.mdVaultPath, settlementVaultPath(date));

    // 当天实体已标 settled=1。
    final schedules = await h.lsDb.listSchedulesByDate(date);
    expect(schedules.first.settled, isTrue);
  });

  test('settleDay 幂等：同一天二次沉淀 → overwritten=true', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    const date = '2026-06-24';
    await batchReplaceQuickNotes(h.lsDb, date, [
      QuickNote(
        id: 'qn-1',
        date: date,
        content: '一条快速记录',
        createdAt: '${date}T09:30:00.000',
        updatedAt: '${date}T09:30:00.000',
      ),
    ]);

    await h.service.settleDay(date);
    final result = await h.service.settleDay(date);
    expect(result.status, SettlementStatus.settled);
    expect(result.overwritten, isTrue);
  });
}

class _Harness {
  const _Harness({required this.temp, required this.service, required this.lsDb});

  final Directory temp;
  final ReviewPrecipitateService service;
  final LifescaleDbService lsDb;

  static Future<_Harness> create() async {
    final temp = await Directory.systemTemp.createTemp('lifescale_settle_');
    await AppPaths.initForTest(temp.path);
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PrefsStore(sharedPrefs);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
      ..interceptors.add(MockApiInterceptor(scenario: 'normal'));
    final client = ApiClient(dio: dio, tokenStore: MemorySecureTokenStore());
    final lsDb = LifescaleDbService();
    await lsDb.get();
    final vaultRepo = VaultRepository(VaultApi(client), DatabaseService(), prefs);
    final mutation = DailyMutationService(vaultRepo, lsDb);
    return _Harness(
      temp: temp,
      service: ReviewPrecipitateService(mutation),
      lsDb: lsDb,
    );
  }

  Future<void> dispose() async {
    await DatabaseService().close();
    await LifescaleDbService().close();
    await temp.delete(recursive: true);
  }
}
