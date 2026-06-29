import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../attachments/data/attachment_service.dart';
import 'data/vault_repository.dart';

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(prefsStoreProvider),
  ),
);

/// 附件本地缓存服务（开源本地版）：仅本地读写，无云端上传/下载。
final attachmentServiceProvider = Provider<AttachmentService>(
  (ref) => AttachmentService(),
);
