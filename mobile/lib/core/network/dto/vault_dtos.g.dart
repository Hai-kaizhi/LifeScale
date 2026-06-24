// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VaultChangeSummaryImpl _$$VaultChangeSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$VaultChangeSummaryImpl(
  vaultPath: json['vaultPath'] as String,
  contentHash: json['contentHash'] as String,
  version: (json['version'] as num).toInt(),
  serverMtime: json['serverMtime'] as String,
  status: json['status'] as String,
  size: (json['size'] as num).toInt(),
);

Map<String, dynamic> _$$VaultChangeSummaryImplToJson(
  _$VaultChangeSummaryImpl instance,
) => <String, dynamic>{
  'vaultPath': instance.vaultPath,
  'contentHash': instance.contentHash,
  'version': instance.version,
  'serverMtime': instance.serverMtime,
  'status': instance.status,
  'size': instance.size,
};

_$VaultChangesDataImpl _$$VaultChangesDataImplFromJson(
  Map<String, dynamic> json,
) => _$VaultChangesDataImpl(
  changes:
      (json['changes'] as List<dynamic>?)
          ?.map((e) => VaultChangeSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <VaultChangeSummary>[],
  serverTime: json['serverTime'] as String,
  nextCursor: json['nextCursor'] as String?,
  hasMore: json['hasMore'] as bool? ?? false,
);

Map<String, dynamic> _$$VaultChangesDataImplToJson(
  _$VaultChangesDataImpl instance,
) => <String, dynamic>{
  'changes': instance.changes,
  'serverTime': instance.serverTime,
  'nextCursor': instance.nextCursor,
  'hasMore': instance.hasMore,
};

_$VaultFileDataImpl _$$VaultFileDataImplFromJson(Map<String, dynamic> json) =>
    _$VaultFileDataImpl(
      vaultPath: json['vaultPath'] as String,
      content: json['content'] as String,
      contentHash: json['contentHash'] as String,
      version: (json['version'] as num).toInt(),
      serverMtime: json['serverMtime'] as String,
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$$VaultFileDataImplToJson(_$VaultFileDataImpl instance) =>
    <String, dynamic>{
      'vaultPath': instance.vaultPath,
      'content': instance.content,
      'contentHash': instance.contentHash,
      'version': instance.version,
      'serverMtime': instance.serverMtime,
      'size': instance.size,
    };

_$VaultPushPayloadImpl _$$VaultPushPayloadImplFromJson(
  Map<String, dynamic> json,
) => _$VaultPushPayloadImpl(
  vaultPath: json['vaultPath'] as String,
  content: json['content'] as String?,
  ifMatchHash: json['ifMatchHash'] as String?,
  deviceId: json['deviceId'] as String?,
);

Map<String, dynamic> _$$VaultPushPayloadImplToJson(
  _$VaultPushPayloadImpl instance,
) => <String, dynamic>{
  'vaultPath': instance.vaultPath,
  'content': instance.content,
  'ifMatchHash': instance.ifMatchHash,
  'deviceId': instance.deviceId,
};

_$ConflictViewImpl _$$ConflictViewImplFromJson(Map<String, dynamic> json) =>
    _$ConflictViewImpl(
      baseHash: json['baseHash'] as String?,
      theirsHash: json['theirsHash'] as String?,
      theirsContent: json['theirsContent'] as String?,
      conflictCopyPath: json['conflictCopyPath'] as String?,
      conflictId: (json['conflictId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$ConflictViewImplToJson(_$ConflictViewImpl instance) =>
    <String, dynamic>{
      'baseHash': instance.baseHash,
      'theirsHash': instance.theirsHash,
      'theirsContent': instance.theirsContent,
      'conflictCopyPath': instance.conflictCopyPath,
      'conflictId': instance.conflictId,
    };

_$ConflictItemImpl _$$ConflictItemImplFromJson(Map<String, dynamic> json) =>
    _$ConflictItemImpl(
      conflictId: (json['conflictId'] as num).toInt(),
      vaultPath: json['vaultPath'] as String,
      mineHash: json['mineHash'] as String?,
      theirsHash: json['theirsHash'] as String?,
      theirsContent: json['theirsContent'] as String? ?? '',
      conflictCopyPath: json['conflictCopyPath'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] as String?,
    );

Map<String, dynamic> _$$ConflictItemImplToJson(_$ConflictItemImpl instance) =>
    <String, dynamic>{
      'conflictId': instance.conflictId,
      'vaultPath': instance.vaultPath,
      'mineHash': instance.mineHash,
      'theirsHash': instance.theirsHash,
      'theirsContent': instance.theirsContent,
      'conflictCopyPath': instance.conflictCopyPath,
      'status': instance.status,
      'createdAt': instance.createdAt,
    };

_$ConflictResolvePayloadImpl _$$ConflictResolvePayloadImplFromJson(
  Map<String, dynamic> json,
) => _$ConflictResolvePayloadImpl(
  strategy: json['strategy'] as String,
  content: json['content'] as String?,
);

Map<String, dynamic> _$$ConflictResolvePayloadImplToJson(
  _$ConflictResolvePayloadImpl instance,
) => <String, dynamic>{
  'strategy': instance.strategy,
  'content': instance.content,
};

_$VaultPushResultImpl _$$VaultPushResultImplFromJson(
  Map<String, dynamic> json,
) => _$VaultPushResultImpl(
  outcome: json['outcome'] as String,
  data: json['data'] == null
      ? null
      : VaultFileData.fromJson(json['data'] as Map<String, dynamic>),
  conflict: json['conflict'] == null
      ? null
      : ConflictView.fromJson(json['conflict'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$VaultPushResultImplToJson(
  _$VaultPushResultImpl instance,
) => <String, dynamic>{
  'outcome': instance.outcome,
  'data': instance.data,
  'conflict': instance.conflict,
};

_$AttachmentUploadResultImpl _$$AttachmentUploadResultImplFromJson(
  Map<String, dynamic> json,
) => _$AttachmentUploadResultImpl(
  hash: json['hash'] as String,
  size: (json['size'] as num).toInt(),
  path: json['path'] as String,
);

Map<String, dynamic> _$$AttachmentUploadResultImplToJson(
  _$AttachmentUploadResultImpl instance,
) => <String, dynamic>{
  'hash': instance.hash,
  'size': instance.size,
  'path': instance.path,
};
