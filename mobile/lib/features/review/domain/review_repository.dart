import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../daily_markdown/domain/daily_doc.dart';
import '../data/review_scheme.dart';
import 'review_models.dart';

/// 复盘仓库：方案读取（Reviews/scheme.md）+ 当天复盘答案读写（Daily 的 ## 今日复盘 段）。
///
/// 数据源为 **Daily Markdown / Vault Markdown**（单一事实来源）：
/// - 方案：`Reviews/scheme.md`（JSON-in-Markdown），与桌面端 1:1。
/// - 答案：当天 `Daily/<date>.md` 的 `## 今日复盘` 段（`### 题目 <!-- rv:questionId -->`）。
class ReviewRepository {
  const ReviewRepository(this._mutation);

  final DailyMutationService _mutation;

  /// 加载当天复盘：方案（active）+ 当天答案。
  Future<ReviewLoadResult> loadReview(String date) async {
    try {
      // 方案：本地优先 → 云端；无则内置默认方案。
      final schemeMd = await _mutation.readVaultFile(schemeVaultPath);
      final store =
          schemeMd == null ? defaultSchemeStore : parseSchemeDoc(schemeMd);
      // 当天 Daily → review 段（已有答案按 questionId 匹配）。
      final read = await _mutation.readDaily(date);
      final items = buildAnswerItems(
        scheme: store.activeScheme,
        existing: read.model.review,
      );
      final title = _dailyTitle(date);
      final canEdit = date == DateUtil.todayIso();
      final data = ReviewViewData(
        date: date,
        title: title,
        scheme: store.activeScheme,
        items: items,
        canEdit: canEdit,
      );
      return ReviewLoadResult.ready(data);
    } catch (e) {
      return ReviewLoadResult.error('复盘加载失败：$e');
    }
  }

  /// 保存当天复盘：按方案全部题目生成 ReviewEntry[]，写回 Daily 的 ## 今日复盘 段。
  /// 空答案对应空字符串（serialize 时变「暂无。」占位）。
  Future<void> saveReview(String date, List<ReviewAnswerItem> items) async {
    final entries = items
        .map((i) => ReviewEntry(
              questionId: i.question.id,
              title: i.question.title,
              content: i.answer,
            ))
        .toList();
    await _mutation.mutate(
      date,
      (model) => model.copyWith(review: entries),
    );
  }

  /// 清空当天复盘（段变「暂无复盘内容。」占位）。
  Future<void> clearReview(String date) async {
    await _mutation.mutate(
      date,
      (model) => model.copyWith(review: const <ReviewEntry>[]),
    );
  }

  String _dailyTitle(String date) {
    final d = DateUtil.parseIso(date);
    return d == null ? date : DateUtil.dailyTitle(d);
  }
}

/// 复盘加载结果。
class ReviewLoadResult {
  const ReviewLoadResult({required this.status, this.data, this.message});

  final ReviewLoadStatus status;
  final ReviewViewData? data;
  final String? message;

  const ReviewLoadResult.ready(ReviewViewData data)
      : this(status: ReviewLoadStatus.ready, data: data);
  const ReviewLoadResult.error(String message)
      : this(status: ReviewLoadStatus.error, message: message);
}
