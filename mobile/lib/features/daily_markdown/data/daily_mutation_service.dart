import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dto/vault_dtos.dart';
import '../../../core/providers.dart';
import '../../../core/storage/lifescale_db_service.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/util/date_util.dart';
import '../../../core/util/mutation_queue.dart';
import '../../vault/data/vault_repository.dart';
import '../../vault/vault_providers.dart';
import '../data/daily_doc_factory.dart';
import '../data/daily_entities.dart';
import '../domain/daily_doc.dart';

/// Daily 结构化读写引擎（docs/09 SQL-first + 沉淀分层）。
///
/// 真相源 = 本地 SQLite `lifescale.db`（via LifescaleDbService）。当天日程/快速记录/
/// 复盘/今日重点全在此库 CRUD，毫秒级交互。**当天不写 `Daily/*.md`**（docs/09 §5.3：
/// 当天不沉淀 = 笔记侧无当天文档；.md 由沉淀动作生成）。
///
/// 对外接口（mutate/readDaily/readVaultFile）与旧 Markdown-first 版本一致，仅内部
/// 实现从「文件 R-M-W + parser/serializer」换成「SQL batch_replace」。调用方零改动。
class DailyMutationService {
  DailyMutationService(this._vaultRepo, this._lsDb);

  final VaultRepository _vaultRepo;
  final LifescaleDbService _lsDb;

  /// 同一天的多段并发改写串行化（按日期键），防止互相覆盖。
  static final MutationQueue _queue = MutationQueue();

  /// 对当天 Daily 做一次结构化读改写（docs/09 §5.3 SQL CRUD）。
  ///
  /// [apply] 接收基于 SQL 最新实体组装的 [DailyDocModel]，返回修改后的新 model；
  /// 本方法负责把 4 类实体批量写回 SQL（先软删当天再 upsert）。
  /// **当天不写 .md、不标 sync_state dirty**（沉淀 P2 才生成 .md，实体同步 P4 才推送）。
  Future<DailyDocModel> mutate(
    String date,
    DailyDocModel Function(DailyDocModel base) apply,
  ) async {
    return _queue.run('daily:$date', () async {
      // 1. 读最新 SQL 实体。
      final entities = await loadDailyEntities(_lsDb, date);
      final base = entities.isEmpty
          ? DailyDocFactory.createEmpty(_dailyTitle(date))
          : DailyDocModel(
              title: _dailyTitle(date),
              focus: entities.focus,
              schedules: entities.schedules,
              quickNotes: entities.quickNotes,
              review: entities.reviews,
            );
      // 2. 应用调用方的段修改。
      final next = apply(base);
      // 3. 批量写回 SQL（先软删当天再 upsert）。
      await Future.wait([
        batchReplaceSchedules(_lsDb, date, next.schedules),
        batchReplaceQuickNotes(_lsDb, date, next.quickNotes),
        batchReplaceReviews(_lsDb, date, next.review),
        upsertDailyFocus(_lsDb, date, next.focus),
      ]);
      return next;
    });
  }

  /// 只读当天 Daily：从 SQL 归档实体组装（不再读 .md 文件）。
  /// 不写入、不标 dirty。供「今日只读查看」「复盘读取」等读路径复用。
  Future<DailyDocRead> readDaily(String date) async {
    final entities = await loadDailyEntities(_lsDb, date);
    if (entities.isEmpty) {
      return DailyDocRead(
        model: DailyDocFactory.createEmpty(_dailyTitle(date)),
        syncedHash: null,
        baseVersion: null,
      );
    }
    return DailyDocRead(
      model: DailyDocModel(
        title: _dailyTitle(date),
        focus: entities.focus,
        schedules: entities.schedules,
        quickNotes: entities.quickNotes,
        review: entities.reviews,
      ),
      // 文件同步概念，当天 SQL 数据无意义，传 null。
      syncedHash: null,
      baseVersion: null,
    );
  }

  /// 只读任意 vault 文件（本地优先 → 云端），返回原始 Markdown。缺失返回 null。
  /// 用于读取 `Reviews/scheme.md` 等非 Daily 文件（笔记仍 Markdown-first，不走 SQL）。
  Future<String?> readVaultFile(String path) async {
    final local = await VaultStorage.readVaultFile(path);
    if (local != null && local.trim().isNotEmpty) return local;
    final pulled = await _pullFromCloud(path);
    if (pulled == null) return null;
    await _vaultRepo.cacheFile(pulled);
    return pulled.content;
  }

  /// 暴露业务库供沉淀服务（P2 settleDay）复用。
  LifescaleDbService get lsDb => _lsDb;

  /// 暴露 vault 仓库供沉淀服务写 .md + 标 dirty + 推送复用。
  VaultRepository get vaultRepo => _vaultRepo;

  // ============================ 内部 ============================

  Future<VaultFileData?> _pullFromCloud(String path) async {
    final res = await _vaultRepo.getFile(path);
    switch (res) {
      case ApiSuccess(:final data):
        return data;
      case ApiFailure():
        return null;
    }
  }

  String _dailyTitle(String date) {
    final d = DateUtil.parseIso(date);
    return d == null ? date : DateUtil.dailyTitle(d);
  }
}

/// 读路径返回：解析后的 model（syncedHash/baseVersion 为兼容旧接口保留，当天 SQL 态恒 null）。
class DailyDocRead {
  const DailyDocRead({
    required this.model,
    required this.syncedHash,
    required this.baseVersion,
  });

  final DailyDocModel model;
  final String? syncedHash;
  final int? baseVersion;
}

/// Provider：依赖 VaultRepository + LifescaleDbService。
final dailyMutationServiceProvider = Provider<DailyMutationService>(
  (ref) => DailyMutationService(
    ref.watch(vaultRepositoryProvider),
    ref.watch(lifescaleDbServiceProvider),
  ),
);
