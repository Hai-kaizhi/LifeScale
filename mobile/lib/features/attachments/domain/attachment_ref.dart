/// 附件引用结果：上传或解析 Markdown 图片语法后的产物。
///
/// `relPath` 是写入 Markdown 的相对引用 `attachments/<hash>.<ext>`（带扩展名，
/// 与桌面端 `ToastMarkdownEditor` 完全一致），可在多端间可移植。
class AttachmentRef {
  const AttachmentRef({
    required this.hash,
    required this.ext,
    required this.relPath,
  });

  /// 附件内容 SHA-256（与后端 CAS / 下载 URL `{hash}` 段对齐）。
  final String hash;

  /// 扩展名（不含点），如 `png` / `jpg`。
  final String ext;

  /// Markdown 相对引用路径：`attachments/<hash>.<ext>`。
  final String relPath;

  /// 构造相对引用（hash + ext → relPath）。
  static String buildRelPath(String hash, String ext) =>
      'attachments/$hash.$ext';
}

/// MIME → 扩展名映射（对齐桌面端 `ToastMarkdownEditor.tsx` 的 extFromMime）。
/// 仅覆盖移动端 MVP 常见图片格式；未知类型回退 png。
String extFromMime(String mime) {
  switch (mime) {
    case 'image/png':
      return 'png';
    case 'image/jpeg':
      return 'jpg';
    case 'image/gif':
      return 'gif';
    case 'image/webp':
      return 'webp';
    default:
      return 'png';
  }
}

/// Markdown 附件引用正则：`attachments/<hash>.<ext>`（hash 为 64 位 hex）。
/// 与桌面端 `ATTACHMENT_SRC_RE` 同形，用于解析图片语法。
final attachmentRefRegex =
    RegExp(r'^attachments/([0-9a-f]{64})\.(\w+)$');
