import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/vault_storage.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_doc_parser.dart';
import '../../review/data/review_precipitate_service.dart';
import '../domain/phase1_models.dart';
import 'phase1_state.dart';

/// 启动控制器（开源本地版）。
///
/// 私有版在此驱动「登录 → 设备注册 → 云端变更拉取 → 缓存 → 补推」流程；
/// 开源版已移除全部网络/同步逻辑，仅做本地启动：
/// 1. 短暂展示启动页（统一冷启动体验）。
/// 2. 惰性补沉淀（fire-and-forget）。
/// 3. 加载当天本地缓存预览 → ready。
class Phase1Controller extends Notifier<Phase1State> {
  @override
  Phase1State build() {
    Future<void>.microtask(completeBoot);
    return const Phase1State();
  }

  Future<void> completeBoot() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // docs/09 §7.3 惰性补沉淀：扫描「过去日期且未沉淀」的记录逐个沉淀（fire-and-forget）。
    try {
      await ref.read(reviewPrecipitateServiceProvider).lazyBackfillOnAppOpen();
    } catch (_) {
      // 补沉淀失败不影响启动流程。
    }
    final cached = await _loadCachedPreview(
      summary: const SyncSummary(offline: true),
    );
    state = state.copyWith(
      bootComplete: true,
      stage: Phase1Stage.ready,
      preview: cached,
      summary: cached?.syncSummary ?? const SyncSummary(offline: true),
    );
  }

  /// 切换时段色调：转发到全局 [ThemeController]（单一真相）。
  void setTone(AppTone tone) {
    ref.read(themeControllerProvider.notifier).setTone(tone);
  }

  void showFutureFeature(String label) {
    state = state.copyWith(info: '$label 当前阶段暂未开发', clearError: true);
  }

  void clearTransient() {
    state = state.copyWith(clearInfo: true, clearError: true);
  }

  Future<TodayPreview?> _loadCachedPreview({
    required SyncSummary summary,
  }) async {
    final date = DateUtil.todayIso();
    final md = await VaultStorage.readDaily(date);
    if (md == null) return null;
    final parsed = DailyDocParser.parse(md, date: date);
    return TodayPreview(
      date: date,
      title: parsed.model.title.isEmpty
          ? DateUtil.dailyTitle()
          : parsed.model.title,
      model: parsed.model,
      cachedPath: VaultStorage.resolveVaultPath('Daily/$date.md'),
      syncSummary: summary,
    );
  }
}

final phase1ControllerProvider =
    NotifierProvider<Phase1Controller, Phase1State>(Phase1Controller.new);
