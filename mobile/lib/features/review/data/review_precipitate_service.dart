import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/lifescale_db_service.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_doc_serializer.dart';
import '../../daily_markdown/data/daily_entities.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../daily_markdown/domain/daily_doc.dart';

/// Daily 沉淀服务（docs/09 第七章）。
///
/// 把当天 SQLite 结构化实体一次性归档为零注释的干净 .md，写入 `Notes/Daily/<date>.md`，
/// 算 SHA-256 存 `ls_daily_settlement` 供回看对账，并标记当天实体 settled=1。
/// 这是 WAL+Checkpoint 模式的 Checkpoint 动作。与桌面 settlementService.ts 对齐。
class ReviewPrecipitateService {
  ReviewPrecipitateService(this._mutation);

  final DailyMutationService _mutation;

  /// 沉淀某天（docs/09 §7.2）。返回沉淀结果（empty/settled）。
  Future<SettlementResult> settleDay(
    String date, {
    String settledBy = 'manual',
  }) async {
    final db = _mutation.lsDb;
    // 1. 读当天实体（settled 实体仍可读 → 支持覆盖式沉淀）。
    final entities = await loadDailyEntities(db, date);
    if (entities.isEmpty) {
      return SettlementResult(status: SettlementStatus.empty, date: date);
    }

    // 2. serializeClean 生成干净 .md（零注释）。
    final title = _dailyTitle(date);
    final model = DailyDocModel(
      title: title,
      focus: entities.focus,
      schedules: entities.schedules,
      quickNotes: entities.quickNotes,
      review: entities.reviews,
    );
    final cleanMd = DailyDocSerializer.serializeClean(model);
    final mdPath = settlementVaultPath(date);
    final mdContentHash = VaultStorage.hashOf(cleanMd);

    // 3. 落本地沙盒 + 记录本地哈希（开源本地版不再推送云端）。
    await VaultStorage.writeVaultFile(mdPath, cleanMd);
    await _mutation.vaultRepo.upsertLocalSyncState(
      vaultPath: mdPath,
      localHash: mdContentHash,
      status: 'clean',
    );

    // 4. 标记当天实体 settled=1。
    await markDailyEntitiesSettled(db, date);

    // 5. 存 ls_daily_settlement 对账记录。
    final prev = await db.getSettlement(date);
    await db.upsertSettlement(SettlementRow(
      date: date,
      mdContentHash: mdContentHash,
      mdVaultPath: mdPath,
      settledAt: DateTime.now().toUtc().toIso8601String(),
      settledBy: settledBy,
    ));

    return SettlementResult(
      status: SettlementStatus.settled,
      date: date,
      mdVaultPath: mdPath,
      mdContentHash: mdContentHash,
      overwritten: prev != null,
    );
  }

  /// 惰性补沉淀（docs/09 §7.3）：扫描「过去日期且未沉淀」的记录，升序逐个沉淀。
  /// 不依赖定时器；打开应用时执行是可靠兜底。单日失败隔离。
  Future<LazyBackfillResult> lazyBackfillOnAppOpen() async {
    final today = _todayStr();
    final db = _mutation.lsDb;
    final dates = await db.listUnsettledPastDates(today);
    final settledDates = <String>[];
    var skipped = 0;

    for (final date in dates) {
      try {
        final result = await settleDay(date, settledBy: 'lazy-backfill');
        if (result.status == SettlementStatus.settled) {
          settledDates.add(date);
        } else {
          skipped++;
        }
      } catch (_) {
        skipped++; // 单日失败隔离
      }
    }

    return LazyBackfillResult(settledDates: settledDates, skipped: skipped);
  }

  // ============================ 内部 ============================

  String _dailyTitle(String date) {
    final d = DateUtil.parseIso(date);
    return d == null ? date : DateUtil.dailyTitle(d);
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

enum SettlementStatus { empty, settled }

class SettlementResult {
  const SettlementResult({
    required this.status,
    required this.date,
    this.mdVaultPath,
    this.mdContentHash,
    this.overwritten = false,
  });

  final SettlementStatus status;
  final String date;
  final String? mdVaultPath;
  final String? mdContentHash;
  final bool overwritten;
}

class LazyBackfillResult {
  const LazyBackfillResult({required this.settledDates, required this.skipped});

  final List<String> settledDates;
  final int skipped;
}

final reviewPrecipitateServiceProvider = Provider<ReviewPrecipitateService>(
  (ref) => ReviewPrecipitateService(ref.watch(dailyMutationServiceProvider)),
);
