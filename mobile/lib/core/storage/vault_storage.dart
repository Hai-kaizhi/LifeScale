import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../util/crypto_util.dart';
import 'app_paths.dart';

/// 本地文件缓存读写（App 沙盒内）。仅参与 `.md` 的 Daily/Vault 文件流；
/// 附件按 hash 单独缓存。原子写 = `.tmp` + rename。
class VaultStorage {
  const VaultStorage._();

  static final Map<String, Future<void>> _writeChains = {};

  /// 写入每日文档，返回沙盒绝对路径。
  static Future<String> writeDaily(String date, String markdown) async {
    final path = p.join(AppPaths.dailyDir, '$date.md');
    await _atomicWriteString(path, markdown);
    return path;
  }

  /// 按 Vault 相对路径写入 Markdown 缓存，返回沙盒绝对路径。
  static Future<String> writeVaultFile(
    String vaultPath,
    String markdown,
  ) async {
    final path = resolveVaultPath(vaultPath);
    await Directory(p.dirname(path)).create(recursive: true);
    await _atomicWriteString(path, markdown);
    return path;
  }

  static Future<String?> readVaultFile(String vaultPath) async {
    final path = resolveVaultPath(vaultPath);
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  static String resolveVaultPath(String vaultPath) {
    final normalized = p.url.normalize(vaultPath.replaceAll('\\', '/'));
    if (normalized.startsWith('../') ||
        normalized == '..' ||
        p.isAbsolute(normalized)) {
      throw ArgumentError('非法 Vault 路径：$vaultPath');
    }
    return p.normalize(p.join(AppPaths.appDocs, normalized));
  }

  /// 读取每日文档，不存在返回 null。
  static Future<String?> readDaily(String date) async {
    final path = p.join(AppPaths.dailyDir, '$date.md');
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  /// 列出所有 `.md` 文件名（按名升序）。
  static Future<List<String>> listDailyNames() async {
    final dir = Directory(AppPaths.dailyDir);
    if (!await dir.exists()) return const [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.md'))
        .map((e) => p.basename(e.path))
        .toList();
    files.sort();
    return files;
  }

  static Future<void> _atomicWriteString(String path, String content) async {
    final previous = _writeChains[path] ?? Future<void>.value();
    final completer = Completer<void>();
    final next = previous
        .catchError((_) {})
        .then((_) async {
          final tmp =
              '$path.${DateTime.now().microsecondsSinceEpoch}.${identityHashCode(content)}.tmp';
          final f = File(tmp);
          final sink = f.openWrite();
          try {
            sink.write(content);
            await sink.flush();
          } finally {
            await sink.close();
          }
          final target = File(path);
          if (await target.exists()) {
            await target.delete();
          }
          await File(tmp).rename(path);
          completer.complete();
        })
        .catchError((Object error, StackTrace stackTrace) {
          completer.completeError(error, stackTrace);
        });
    _writeChains[path] = next.whenComplete(() {
      if (_writeChains[path] == next) {
        _writeChains.remove(path);
      }
    });
    return completer.future;
  }

  /// 文本内容 SHA-256（与后端/桌面字节对齐）。
  static String hashOf(String content) => CryptoUtil.sha256Hex(content);

  // ---- 附件（内容寻址，按 hash 缓存；引用路径带扩展名 attachments/<hash>.<ext>）----

  /// 附件缓存绝对路径（带扩展名，与 Markdown 引用 `attachments/<hash>.<ext>` 一致）。
  static String attachmentPath(String hash, String ext) =>
      p.join(AppPaths.attachmentsDir, '$hash.$ext');

  /// 写入附件字节到沙盒缓存（原子写 + 按路径串行，避免并发损坏）。
  /// 返回沙盒绝对路径。
  static Future<String> writeAttachmentBytes(
    String hash,
    String ext,
    Uint8List bytes,
  ) async {
    final path = attachmentPath(hash, ext);
    await _atomicWriteBytes(path, bytes);
    return path;
  }

  /// 读取附件缓存字节；不存在返回 null。
  static Future<Uint8List?> readAttachmentBytes(String hash, String ext) async {
    final f = File(attachmentPath(hash, ext));
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  /// 附件缓存是否存在。
  static Future<bool> attachmentExists(String hash, String ext) =>
      File(attachmentPath(hash, ext)).exists();

  static Future<void> _atomicWriteBytes(String path, Uint8List bytes) async {
    final previous = _writeChains[path] ?? Future<void>.value();
    final completer = Completer<void>();
    final next = previous
        .catchError((_) {})
        .then((_) async {
          final tmp =
              '$path.${DateTime.now().microsecondsSinceEpoch}.${identityHashCode(bytes)}.tmp';
          final sink = File(tmp).openWrite();
          try {
            sink.add(bytes);
            await sink.flush();
          } finally {
            await sink.close();
          }
          final target = File(path);
          if (await target.exists()) {
            await target.delete();
          }
          await File(tmp).rename(path);
          completer.complete();
        })
        .catchError((Object error, StackTrace stackTrace) {
          completer.completeError(error, stackTrace);
        });
    _writeChains[path] = next.whenComplete(() {
      if (_writeChains[path] == next) {
        _writeChains.remove(path);
      }
    });
    return completer.future;
  }
}
