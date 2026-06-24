import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault_dtos.freezed.dart';
part 'vault_dtos.g.dart';

/// 单条变更摘要（无正文）。`status == 'deleted'` 表示墓碑。
@freezed
class VaultChangeSummary with _$VaultChangeSummary {
  const factory VaultChangeSummary({
    required String vaultPath,
    required String contentHash,
    required int version,
    required String serverMtime,
    required String status,
    required int size,
  }) = _VaultChangeSummary;

  factory VaultChangeSummary.fromJson(Map<String, dynamic> json) =>
      _$VaultChangeSummaryFromJson(json);
}

/// `GET /vault/changes` 的 data：变更列表 + 游标分页。
@freezed
class VaultChangesData with _$VaultChangesData {
  const factory VaultChangesData({
    @Default(<VaultChangeSummary>[]) List<VaultChangeSummary> changes,
    required String serverTime,
    String? nextCursor,
    @Default(false) bool hasMore,
  }) = _VaultChangesData;

  factory VaultChangesData.fromJson(Map<String, dynamic> json) =>
      _$VaultChangesDataFromJson(json);
}

/// `GET /vault/files` 的 data：文件正文 + hash + 版本。
@freezed
class VaultFileData with _$VaultFileData {
  const factory VaultFileData({
    required String vaultPath,
    required String content,
    required String contentHash,
    required int version,
    required String serverMtime,
    required int size,
  }) = _VaultFileData;

  factory VaultFileData.fromJson(Map<String, dynamic> json) =>
      _$VaultFileDataFromJson(json);
}

/// `PUT /vault/files` 请求体。`ifMatchHash` 为乐观锁 token（上次同步到的服务端 hash）。
@freezed
class VaultPushPayload with _$VaultPushPayload {
  const factory VaultPushPayload({
    required String vaultPath,
    String? content,
    String? ifMatchHash,
    String? deviceId,
  }) = _VaultPushPayload;

  factory VaultPushPayload.fromJson(Map<String, dynamic> json) =>
      _$VaultPushPayloadFromJson(json);
}

/// 冲突视图（`outcome == 'conflict'` 时填充）。
@freezed
class ConflictView with _$ConflictView {
  const factory ConflictView({
    String? baseHash,
    String? theirsHash,
    String? theirsContent,
    String? conflictCopyPath,
    int? conflictId,
  }) = _ConflictView;

  factory ConflictView.fromJson(Map<String, dynamic> json) =>
      _$ConflictViewFromJson(json);
}

/// 冲突列表项（`GET /vault/conflicts` 的元素）：含双方内容，供冲突中心页展示与处理。
@freezed
class ConflictItem with _$ConflictItem {
  const factory ConflictItem({
    required int conflictId,
    required String vaultPath,
    String? mineHash,
    String? theirsHash,
    @Default('') String theirsContent,
    String? conflictCopyPath,
    String? status,
    String? createdAt,
  }) = _ConflictItem;

  factory ConflictItem.fromJson(Map<String, dynamic> json) =>
      _$ConflictItemFromJson(json);
}

/// 解决冲突请求体（`POST /vault/conflicts/{id}/resolve`）。
/// `strategy`: `keepMine`（以 content 覆盖正本）/ `keepTheirs`（保留正本）。
@freezed
class ConflictResolvePayload with _$ConflictResolvePayload {
  const factory ConflictResolvePayload({
    required String strategy,
    String? content,
  }) = _ConflictResolvePayload;

  factory ConflictResolvePayload.fromJson(Map<String, dynamic> json) =>
      _$ConflictResolvePayloadFromJson(json);
}

/// `PUT /vault/files` 的 data。`outcome` 为判别字段：
/// `created` | `ok` | `merged` | `conflict`（非 HTTP 状态码）。
@freezed
class VaultPushResult with _$VaultPushResult {
  const factory VaultPushResult({
    required String outcome,
    VaultFileData? data,
    ConflictView? conflict,
  }) = _VaultPushResult;

  factory VaultPushResult.fromJson(Map<String, dynamic> json) =>
      _$VaultPushResultFromJson(json);
}

/// `POST /vault/attachments` 的 data：按 hash 去重后的上传结果。
@freezed
class AttachmentUploadResult with _$AttachmentUploadResult {
  const factory AttachmentUploadResult({
    required String hash,
    required int size,
    required String path,
  }) = _AttachmentUploadResult;

  factory AttachmentUploadResult.fromJson(Map<String, dynamic> json) =>
      _$AttachmentUploadResultFromJson(json);
}
