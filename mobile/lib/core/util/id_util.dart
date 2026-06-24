import 'package:uuid/uuid.dart';

/// 稳定 ID 生成（与桌面端 `newId()` 语义一致：UUID v4）。
/// 用于 deviceId（一次性）与 Daily Markdown 解析时为老文件补 ID。
class IdUtil {
  const IdUtil._();

  static String newId() => const Uuid().v4();
}
