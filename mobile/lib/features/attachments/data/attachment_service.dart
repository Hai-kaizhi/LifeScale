import 'dart:typed_data';

import '../../../core/storage/vault_storage.dart';
import '../../../core/util/crypto_util.dart';
import '../domain/attachment_ref.dart';

/// 附件本地缓存服务（开源本地版）。
///
/// 私有版在此之上叠加云端 CAS 上传/下载；开源版已移除全部网络调用，仅保留本地缓存：
/// - **读**：本地缓存命中返回字节，否则返回 null（由 UI 显示占位）。
/// - **写入**：算 hash → 写本地缓存 → 返回 `AttachmentRef`（relPath 直接插入 Markdown）。
///
/// 所有方法幂等、并发安全（写串行在 [VaultStorage] 内按路径保证）。
class AttachmentService {
  AttachmentService();

  /// 读取本地缓存字节；不存在返回 null。
  Future<Uint8List?> readCache(String hash, String ext) =>
      VaultStorage.readAttachmentBytes(hash, ext);

  /// 本地缓存是否存在。
  Future<bool> hasCache(String hash, String ext) =>
      VaultStorage.attachmentExists(hash, ext);

  /// 确保附件可用：本地有→直接返回；无→返回 null（开源本地版不下载）。
  ///
  /// 接口签名与私有版一致，便于 Markdown 图片渲染统一调用。
  Future<Uint8List?> ensure(String hash, String ext) =>
      VaultStorage.readAttachmentBytes(hash, ext);

  /// 写入图片字节：算 hash → 写本地缓存 → 返回 [AttachmentRef]。
  /// 返回的 `relPath` 可直接插入 Markdown `![](<relPath>)`。
  Future<AttachmentRef> upload(Uint8List bytes, String ext) async {
    final hash = CryptoUtil.sha256BytesHex(bytes);
    await VaultStorage.writeAttachmentBytes(hash, ext, bytes);
    return AttachmentRef(
      hash: hash,
      ext: ext,
      relPath: AttachmentRef.buildRelPath(hash, ext),
    );
  }
}
