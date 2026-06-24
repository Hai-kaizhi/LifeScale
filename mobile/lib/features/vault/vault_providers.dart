import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../attachments/data/attachment_service.dart';
import 'data/vault_api.dart';
import 'data/vault_repository.dart';

final vaultApiProvider = Provider<VaultApi>(
  (ref) => VaultApi(ref.watch(apiClientProvider)),
);

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(
    ref.watch(vaultApiProvider),
    ref.watch(databaseServiceProvider),
    ref.watch(prefsStoreProvider),
  ),
);

/// 附件懒拉取 + 缓存 + 上传服务（阶段八）。
final attachmentServiceProvider = Provider<AttachmentService>(
  (ref) => AttachmentService(ref.watch(vaultApiProvider)),
);
