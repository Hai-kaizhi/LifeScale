import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用沙盒路径解析（在 bootstrap 阶段一次性初始化）。
///
/// 布局与桌面端 vault 根目录一致（但落在 App 沙盒内，而非用户自选目录）：
/// - `Daily/<YYYY-MM-DD>.md`：每日文档（历史遗留，P1 后当天不再生成）
/// - `Notes/Daily/<YYYY-MM-DD>.md`：沉淀产物（P2 干净 .md 快照）
/// - `attachments/<hash>`：附件内容寻址缓存
/// - `.lifescale/sync.db`：本地同步索引
/// - `.lifescale/lifescale.db`：业务真相源库（docs/09 §6.1，与 sync.db 分离）
class AppPaths {
  AppPaths._();

  static late String appDocs;
  static late String dailyDir;
  static late String notesDailyDir;
  static late String attachmentsDir;
  static late String metaDir;
  static late String dbPath;
  static late String lifescaleDbPath;

  /// 解析并创建缓存目录结构。
  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    appDocs = docs.path;
    dailyDir = p.join(docs.path, 'Daily');
    notesDailyDir = p.join(docs.path, 'Notes', 'Daily');
    attachmentsDir = p.join(docs.path, 'attachments');
    metaDir = p.join(docs.path, '.lifescale');
    dbPath = p.join(metaDir, 'sync.db');
    lifescaleDbPath = p.join(metaDir, 'lifescale.db');

    await Directory(dailyDir).create(recursive: true);
    await Directory(notesDailyDir).create(recursive: true);
    await Directory(attachmentsDir).create(recursive: true);
    await Directory(metaDir).create(recursive: true);
  }

  /// Test-only helper: points the sandbox at a temporary directory without
  /// touching platform path_provider channels.
  static Future<void> initForTest(String docsPath) async {
    appDocs = docsPath;
    dailyDir = p.join(docsPath, 'Daily');
    notesDailyDir = p.join(docsPath, 'Notes', 'Daily');
    attachmentsDir = p.join(docsPath, 'attachments');
    metaDir = p.join(docsPath, '.lifescale');
    dbPath = p.join(metaDir, 'sync.db');
    lifescaleDbPath = p.join(metaDir, 'lifescale.db');

    await Directory(dailyDir).create(recursive: true);
    await Directory(notesDailyDir).create(recursive: true);
    await Directory(attachmentsDir).create(recursive: true);
    await Directory(metaDir).create(recursive: true);
  }
}
