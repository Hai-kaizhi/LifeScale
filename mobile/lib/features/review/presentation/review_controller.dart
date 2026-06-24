import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../review/data/review_precipitate_service.dart';
import '../data/review_scheme.dart';
import '../domain/review_models.dart';
import '../domain/review_repository.dart';

/// 复盘页控制器。
class ReviewController extends Notifier<ReviewState> {
  late String _date;

  @override
  ReviewState build() {
    _date = DateUtil.todayIso();
    Future<void>.microtask(loadReview);
    return const ReviewState();
  }

  /// 初始化指定日期（来自路由 query）。在 widget build 后立即调用。
  void setDate(String date) {
    if (date == _date) return;
    _date = date;
  }

  String get date => _date;
  bool get canEdit => _date == DateUtil.todayIso();

  Future<void> loadReview() async {
    state = state.copyWith(status: ReviewLoadStatus.loading, clearData: true);
    final result = await ref.read(reviewRepositoryProvider).loadReview(_date);
    switch (result.status) {
      case ReviewLoadStatus.ready:
        state = state.copyWith(
          status: ReviewLoadStatus.ready,
          data: result.data,
          clearMessage: true,
        );
      case ReviewLoadStatus.error:
        state = state.copyWith(
          status: ReviewLoadStatus.error,
          message: result.message ?? '复盘加载失败',
        );
      default:
        break;
    }
  }

  /// 编辑某题答案（内存态，保存时统一写回）。
  void updateAnswer(String questionId, String text) {
    final data = state.data;
    if (data == null) return;
    final items = data.items
        .map((i) =>
            i.question.id == questionId ? i.copyWith(answer: text) : i)
        .toList();
    state = state.copyWith(data: data.copyWith(items: items));
  }

  /// 保存复盘（写回当天 Daily 的 ## 今日复盘 段）。
  Future<bool> save() async {
    final data = state.data;
    if (data == null || !canEdit) return false;
    state = state.copyWith(saving: true, clearMessage: true);
    try {
      await ref.read(reviewRepositoryProvider).saveReview(_date, data.items);
      state = state.copyWith(
        saving: false,
        message: '复盘已保存',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        saving: false,
        message: '保存失败：$e',
      );
      return false;
    }
  }

  /// 沉淀当天复盘为 Vault 文档。返回提示文案。
  Future<String> precipitate() async {
    final data = state.data;
    if (data == null) return '复盘加载中，请稍候';
    if (!data.hasAnswer) return '请先填写复盘内容，再进行沉淀';
    // 先确保最新答案已写回 Daily，再沉淀。
    if (canEdit) {
      await ref.read(reviewRepositoryProvider).saveReview(_date, data.items);
    }
    state = state.copyWith(saving: true, clearMessage: true);
    try {
      final result =
          await ref.read(reviewPrecipitateServiceProvider).settleDay(_date);
      final msg = result.overwritten
          ? '已重新沉淀到 ${result.mdVaultPath}'
          : (result.status == SettlementStatus.empty
              ? '当天没有可沉淀的内容'
              : '已沉淀到 ${result.mdVaultPath}');
      state = state.copyWith(saving: false, message: msg);
      return msg;
    } catch (e) {
      state = state.copyWith(saving: false, message: '沉淀失败：$e');
      return '沉淀失败：$e';
    }
  }
}

/// 复盘方案当前激活方案（供 UI 展示方案名）。
ReviewQuestionScheme activeSchemeOf(ReviewViewData? data) =>
    data?.scheme ?? defaultSchemeStore.activeScheme;

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(dailyMutationServiceProvider)),
);

final reviewControllerProvider = NotifierProvider<ReviewController, ReviewState>(
  ReviewController.new,
);
