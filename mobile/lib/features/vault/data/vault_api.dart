import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dto/daily_entity_dtos.dart';
import '../../../core/network/dto/vault_dtos.dart';

/// Vault 同步远程数据源（`/api/vault`、`/api/vault/attachments`）。
///
/// Step 0 仅 `changes` 被验收调用；`getFile`/`push`/附件方法随阶段三、八启用；
/// `listConflicts`/`resolveConflict` 随阶段九启用。
class VaultApi {
  VaultApi(this._client);

  final ApiClient _client;

  /// 拉取变更摘要（游标分页）。
  Future<ApiResult<VaultChangesData>> changes({String? since, int? limit}) =>
      _client.get(
        ApiEndpoints.vaultChanges,
        query: {
          if (since != null) 'since': since,
          if (limit != null) 'limit': limit,
        },
        fromJsonT: (j) => VaultChangesData.fromJson(j as Map<String, dynamic>),
      );

  Future<ApiResult<VaultFileData>> getFile(String path) => _client.get(
    ApiEndpoints.vaultFiles,
    query: {'path': path},
    fromJsonT: (j) => VaultFileData.fromJson(j as Map<String, dynamic>),
  );

  /// 推送文件（PUT，启用按 path 去重）。
  Future<ApiResult<VaultPushResult>> push(VaultPushPayload payload) =>
      _client.put(
    ApiEndpoints.vaultFiles,
    body: payload.toJson(),
    dedup: true,
    fromJsonT: (j) => VaultPushResult.fromJson(j as Map<String, dynamic>),
  );

  Future<ApiResult<AttachmentUploadResult>> uploadAttachment(
    Uint8List bytes,
    String filename,
  ) => _client.uploadAttachment(ApiEndpoints.vaultAttachments, bytes, filename);

  Future<Uint8List?> downloadAttachment(String hash) =>
      _client.downloadBytes(ApiEndpoints.attachment(hash));

  /// 阶段九：列出当前用户未解决冲突（含 theirs 内容预览）。
  Future<ApiResult<List<ConflictItem>>> listConflicts() => _client.get(
    ApiEndpoints.vaultConflicts,
    fromJsonT: (j) => (j as List<dynamic>)
        .map((e) => ConflictItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// 阶段九：解决冲突。keepMine 时 content 为本机内容；返回更新后的正本。
  Future<ApiResult<VaultFileData>> resolveConflict(
    int conflictId,
    ConflictResolvePayload payload,
  ) => _client.post(
    ApiEndpoints.resolveConflict(conflictId),
    body: payload.toJson(),
    fromJsonT: (j) => VaultFileData.fromJson(j as Map<String, dynamic>),
  );

  /// 当天实体同步（docs/09 §9.3）：推送 4 类当天未沉淀实体（LWW）。
  Future<ApiResult<DailyEntitySyncResult>> pushDailyEntities(
    DailyEntityPushPayload payload,
  ) => _client.put(
    ApiEndpoints.vaultDailyEntities,
    body: payload.toJson(),
    fromJsonT: (j) => DailyEntitySyncResult.fromJson(j as Map<String, dynamic>),
  );

  /// 当天实体同步：增量变更（按 updatedAt 游标，含墓碑）。
  Future<ApiResult<DailyEntityChangesData>> getDailyEntityChanges({
    String? since,
    int? limit,
  }) => _client.get(
    ApiEndpoints.vaultDailyEntityChanges,
    query: {
      if (since != null) 'since': since,
      if (limit != null) 'limit': limit,
    },
    fromJsonT: (j) => DailyEntityChangesData.fromJson(j as Map<String, dynamic>),
  );
}
