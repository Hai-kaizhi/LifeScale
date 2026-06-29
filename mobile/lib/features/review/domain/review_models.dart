import '../../daily_markdown/domain/daily_doc.dart';
import '../data/review_scheme.dart';

/// 复盘页加载状态。
enum ReviewLoadStatus { loading, ready, empty, error }

/// 单题作答的 UI 状态（题目定义 + 当前答案）。
class ReviewAnswerItem {
  const ReviewAnswerItem({
    required this.question,
    required this.answer,
  });

  final ReviewQuestion question;
  final String answer;

  ReviewAnswerItem copyWith({ReviewQuestion? question, String? answer}) =>
      ReviewAnswerItem(
        question: question ?? this.question,
        answer: answer ?? this.answer,
      );
}

/// 复盘页视图数据。
class ReviewViewData {
  const ReviewViewData({
    required this.date,
    required this.title,
    required this.scheme,
    required this.items,
    required this.canEdit,
  });

  final String date;
  final String title;
  final ReviewQuestionScheme scheme;
  final List<ReviewAnswerItem> items;
  final bool canEdit;

  bool get hasAnswer =>
      items.any((i) => i.answer.trim().isNotEmpty);

  ReviewViewData copyWith({
    String? date,
    String? title,
    ReviewQuestionScheme? scheme,
    List<ReviewAnswerItem>? items,
    bool? canEdit,
  }) =>
      ReviewViewData(
        date: date ?? this.date,
        title: title ?? this.title,
        scheme: scheme ?? this.scheme,
        items: items ?? this.items,
        canEdit: canEdit ?? this.canEdit,
      );
}

/// 复盘页状态。
class ReviewState {
  const ReviewState({
    this.status = ReviewLoadStatus.loading,
    this.data,
    this.message,
    this.saving = false,
  });

  final ReviewLoadStatus status;
  final ReviewViewData? data;
  final String? message;
  final bool saving;

  ReviewState copyWith({
    ReviewLoadStatus? status,
    ReviewViewData? data,
    bool clearData = false,
    String? message,
    bool clearMessage = false,
    bool? saving,
  }) =>
      ReviewState(
        status: status ?? this.status,
        data: clearData ? null : data ?? this.data,
        message: clearMessage ? null : message ?? this.message,
        saving: saving ?? this.saving,
      );
}

/// 把 Daily Markdown 解析出的 review 段与方案题目对齐为作答列表。
/// 历史复盘优先匹配其 questionId（official-* 永久稳定 / custom UUID）。
List<ReviewAnswerItem> buildAnswerItems({
  required ReviewQuestionScheme scheme,
  required List<ReviewEntry> existing,
}) {
  final byId = {for (final e in existing) e.questionId: e.content};
  return scheme.questions
      .map((q) => ReviewAnswerItem(
            question: q,
            answer: byId[q.id] ?? '',
          ))
      .toList();
}
