import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/database_service.dart';
import 'storage/lifescale_db_service.dart';
import 'storage/prefs_store.dart';

/// 非敏感偏好。需在 main 中以 SharedPreferences 实例 override。
final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw UnimplementedError(
    'prefsStoreProvider 必须在 main 中用 SharedPreferences override',
  ),
);

/// 本地同步索引 DB（sync.db）。
///
/// 开源本地版仅做本地文件索引（vault_path → hash/state），不再有远端同步语义；
/// 保留此库是因为沉淀/笔记写入路径仍借助 sync_state 记录本地哈希，便于将来扩展。
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

/// 业务真相源 DB（lifescale.db，docs/09 §6.1，与 sync.db 物理分离）。
final lifescaleDbServiceProvider = Provider<LifescaleDbService>(
  (ref) => LifescaleDbService(),
);
