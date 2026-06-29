import 'package:freezed_annotation/freezed_annotation.dart';

part 'quick_note.freezed.dart';

/// 快速记录。字段对齐桌面端 `shared/types/quickNote.ts`。
/// `sourceDevice` 固定 `'desktop'`（与桌面端一致，多端枚举待后续统一）。
@freezed
class QuickNote with _$QuickNote {
  const factory QuickNote({
    required String id,
    required String date,
    required String content,
    @Default('desktop') String sourceDevice,
    @Default('active') String status,
    required String createdAt,
    required String updatedAt,
  }) = _QuickNote;
}
