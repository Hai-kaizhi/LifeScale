import '../core/storage/app_paths.dart';
import '../core/storage/database_service.dart';
import '../core/storage/lifescale_db_service.dart';

/// 启动初始化：沙盒缓存目录 + 本地 SQLite（`.lifescale/sync.db` 同步索引 + `lifescale.db` 业务真相源）。
///
/// token 预热（Keystore → 内存缓存）由 AuthController 在 build 时异步完成。
class Bootstrap {
  Bootstrap._();

  static Future<void> run() async {
    await AppPaths.init();
    // 预建本地同步索引库（sync_meta + sync_state）。
    await DatabaseService().get();
    // 预建业务真相源库（docs/09 §6.1，结构化生活数据 SQL-first）。
    await LifescaleDbService().get();
  }
}
