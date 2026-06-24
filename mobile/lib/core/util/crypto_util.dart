import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SHA-256 工具：与后端 `ContentHasher.sha256`、桌面端 `sha256Hex` 字节级对齐
/// （UTF-8 编码 → 小写 64 位 hex）。该 hash 是乐观锁 `ifMatchHash` 的来源，必须一致。
class CryptoUtil {
  const CryptoUtil._();

  /// 文本内容 → 小写 hex。
  static String sha256Hex(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  /// 原始字节 → 小写 hex（附件按 hash 内容寻址）。
  static String sha256BytesHex(Uint8List bytes) =>
      sha256.convert(bytes).toString();
}
