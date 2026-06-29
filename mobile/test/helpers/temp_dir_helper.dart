import 'dart:io';

/// 测试辅助：跨平台安全删除临时目录。
///
/// Windows 下 sqflite/文件句柄释放有延迟，立即 delete 常触发
/// `PathAccessException ... errno = 32 (Sharing Violation)`，
/// 导致 tearDown 抛异常、级联污染后续测试。
///
/// 本函数对删除失败做有限次重试（每次间隔一小段），最终仍失败则静默忽略——
/// 临时目录在系统 temp 下，OS 终会清理，不应阻塞测试流程。
Future<void> safeDeleteTempDir(Directory dir) async {
  if (!dir.existsSync()) return;

  const maxAttempts = 5;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await dir.delete(recursive: true);
      return; // 删除成功
    } on PathAccessException catch (_) {
      // Windows 文件锁（errno 32）：等待句柄释放后重试。
      if (attempt == maxAttempts) {
        // 达到上限仍失败：静默放弃。临时目录留待 OS 清理，不阻塞测试。
        // 忽略而非抛出——测试断言的成败不应被清理阶段的文件锁左右。
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
    } catch (_) {
      // 其他异常同样静默：tearDown 失败不级联污染测试结果。
      return;
    }
  }
}
