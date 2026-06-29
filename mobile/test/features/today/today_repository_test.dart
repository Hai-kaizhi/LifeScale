import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/providers.dart';
import 'package:lifescale_mobile/core/storage/app_paths.dart';
import 'package:lifescale_mobile/core/storage/database_service.dart';
import 'package:lifescale_mobile/core/storage/lifescale_db_service.dart';
import 'package:lifescale_mobile/core/storage/prefs_store.dart';
import 'package:lifescale_mobile/core/util/date_util.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_entities.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_mutation_service.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/daily_doc.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/quick_note.dart';
import 'package:lifescale_mobile/features/daily_markdown/domain/schedule.dart';
import 'package:lifescale_mobile/features/today/data/today_repository.dart';
import 'package:lifescale_mobile/features/today/domain/today_models.dart';
import 'package:lifescale_mobile/features/today/presentation/today_controller.dart';
import 'package:lifescale_mobile/features/vault/data/vault_repository.dart';
import 'package:lifescale_mobile/shared/constants/markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/temp_dir_helper.dart';

/// 今日仓库测试（开源本地版，数据源为本地 SQLite）。
///
/// 验证加载、快速记录写入、任务增删改、重点标记均落到当天 SQL 实体。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().close();
    SharedPreferences.setMockInitialValues({});
  });

  test('normal scenario loads today schedules, notes, focus and review',
      () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);

    final result = await h.repository.loadToday(h.today);

    expect(result.status, TodayLoadStatus.ready);
    expect(result.data!.focus, '完成产品方案初稿');
    expect(result.data!.taskCount, 6);
    expect(result.data!.quickNotes, hasLength(2));
    expect(result.data!.reviewAnsweredCount, 4);
  });

  test('empty scenario returns empty state', () async {
    final h = await _Harness.create('empty');
    addTearDown(h.dispose);

    final result = await h.repository.loadToday(h.today);

    expect(result.status, TodayLoadStatus.empty);
  });

  test('add quick note appends to today and keeps existing notes', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(h.today)).data!;

    final result = await h.repository.addQuickNote(
      h.today,
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
    final base = (await h.repository.loadToday(h.today)).data!;
    final s5 = base.tasks.firstWhere((t) => t.id == 's5');
    expect(s5.completed, isFalse);

    final result = await h.repository.toggleTask(
      h.today,
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

  test('create, update, delete task mutate the schedule section', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final base = (await h.repository.loadToday(h.today)).data!;

    final created = await h.repository.createTask(
      h.today,
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
      h.today,
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
      h.today,
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
    final base = (await h.repository.loadToday(h.today)).data!;

    final result = await h.repository.toggleFocus(
      h.today,
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

  test('controller add quick note writes through', () async {
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

  test('controller allows editing on historical date', () async {
    final h = await _Harness.create('normal');
    addTearDown(h.dispose);
    final container = h.container();
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);

    await controller.loadToday();
    await controller.changeDate(DateUtil.plusDays(h.today, -1)!);
    final ok = await controller.addQuickNote('历史日期也能记录');
    expect(ok, isTrue);
    final state = container.read(todayControllerProvider);
    expect(state.data!.quickNotes.last.content, '历史日期也能记录');
  });
}

class _Harness {
  const _Harness({
    required this.temp,
    required this.prefs,
    required this.today,
    required this.repository,
  });

  final Directory temp;
  final PrefsStore prefs;
  final String today;
  final TodayRepository repository;

  static Future<_Harness> create(String scenario) async {
    final temp = await Directory.systemTemp.createTemp('lifescale_today_');
    await AppPaths.initForTest(temp.path);
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PrefsStore(sharedPrefs);
    final db = DatabaseService();
    final vaultRepo = VaultRepository(db, prefs);
    final lsDb = LifescaleDbService();
    await lsDb.get();
    final today = DateUtil.todayIso();

    // 清掉当天残留，保证干净起点。
    final now = DateTime.now().toUtc().toIso8601String();
    await lsDb.softDeleteSchedulesByDate(today, now);
    await lsDb.softDeleteQuickNotesByDate(today, now);
    await lsDb.softDeleteReviewAnswersByDate(today, now);
    await upsertDailyFocus(lsDb, today, null);

    final mutation = DailyMutationService(vaultRepo, lsDb);

    if (scenario == 'normal') {
      await _seedNormal(lsDb, today);
    }

    return _Harness(
      temp: temp,
      prefs: prefs,
      today: today,
      repository: TodayRepository(mutation),
    );
  }

  ProviderContainer container() => ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
        ],
      );

  Future<void> dispose() async {
    await DatabaseService().close();
    await safeDeleteTempDir(temp);
  }
}

/// 给 'normal' 场景种当日实体数据（SQL-first 真相源）。
///
/// 数据形态对齐原 `MockApiData.todayMarkdown` 种子：
/// 6 个任务（task）+ 4 个时间记录（note）+ 2 条快速记录 + 4 题复盘 + 1 条今日重点。
/// 通过真实业务写函数（batchReplace* / upsertDailyFocus）写入，验证「写→读」完整链路。
Future<void> _seedNormal(LifescaleDbService db, String date) async {
  const work = ScheduleCategory.work;
  const life = ScheduleCategory.life;

  // 6 个任务（task）+ 4 个时间记录（note），对齐原种子。
  final schedules = <Schedule>[
    Schedule(id: 's1', title: '完成产品方案初稿', completed: true, category: work, categoryColor: work.color, type: ScheduleType.task, focus: true, sortOrder: 0, startTime: '09:30', endTime: '10:30', date: date),
    Schedule(id: 's2', title: '与团队同步需求', completed: true, category: work, categoryColor: work.color, type: ScheduleType.task, sortOrder: 1, startTime: '10:45', endTime: '11:30', date: date),
    Schedule(id: 's3', title: '用户调研与分析', completed: true, category: work, categoryColor: work.color, type: ScheduleType.task, sortOrder: 2, startTime: '13:30', endTime: '14:20', date: date),
    Schedule(id: 's4', title: '撰写 PRD 文档', completed: true, category: work, categoryColor: work.color, type: ScheduleType.task, sortOrder: 3, startTime: '15:00', endTime: '16:00', date: date),
    Schedule(id: 's5', title: '阅读 30 分钟', completed: false, category: life, categoryColor: life.color, type: ScheduleType.task, sortOrder: 4, startTime: '17:30', endTime: '18:00', date: date),
    Schedule(id: 's6', title: '运动 30 分钟', completed: false, category: life, categoryColor: life.color, type: ScheduleType.task, sortOrder: 5, startTime: '19:30', endTime: '20:00', date: date),
    Schedule(id: 's7', title: '起床', category: life, categoryColor: life.color, type: ScheduleType.note, sortOrder: 6, startTime: '07:30', endTime: '08:00', date: date),
    Schedule(id: 's8', title: '阅读 30 分钟', category: life, categoryColor: life.color, type: ScheduleType.note, sortOrder: 7, startTime: '08:30', endTime: '09:00', date: date),
    Schedule(id: 's9', title: '同步需求', category: work, categoryColor: work.color, type: ScheduleType.note, sortOrder: 8, startTime: '11:00', endTime: '11:30', date: date),
    Schedule(id: 's10', title: '午休', category: life, categoryColor: life.color, type: ScheduleType.note, sortOrder: 9, startTime: '12:30', endTime: '13:10', date: date),
  ];

  final quickNotes = <QuickNote>[
    QuickNote(id: 'q1', date: date, content: '09:20 今天先把移动端登录链路跑顺', createdAt: '${date}T09:20:00.000Z', updatedAt: '${date}T09:20:00.000Z'),
    QuickNote(id: 'q2', date: date, content: '14:05 下午保持深度工作，减少上下文切换', createdAt: '${date}T14:05:00.000Z', updatedAt: '${date}T14:05:00.000Z'),
  ];

  final reviews = <ReviewEntry>[
    ReviewEntry(questionId: 'r1', title: '今天我做成了什么？', content: '完成产品方案初稿，并把同步初始化链路梳理清楚'),
    ReviewEntry(questionId: 'r2', title: '今天我学到了什么？', content: '移动端先用缓存预览能更稳地承接桌面端内容'),
    ReviewEntry(questionId: 'r3', title: '今天我遇到了什么困难？', content: '阶段边界需要克制，先让同步闭环扎实'),
    ReviewEntry(questionId: 'r4', title: '明天我可以如何做得更好？', content: '保持小步推进，每完成一段就验证一次'),
  ];

  await Future.wait([
    batchReplaceSchedules(db, date, schedules),
    batchReplaceQuickNotes(db, date, quickNotes),
    batchReplaceReviews(db, date, reviews),
    upsertDailyFocus(db, date, '完成产品方案初稿'),
  ]);
}
