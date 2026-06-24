import 'dart:typed_data';

import '../../../core/network/api_result.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/util/crypto_util.dart';
import '../../vault/data/vault_api.dart';
import '../domain/attachment_ref.dart';

/// 附件懒拉取 + 本地缓存 + 轻量上传服务（阶段八核心）。
///
/// 与桌面端 `VaultSyncEngine` 的附件逻辑同形：
/// - **读**：本地缓存优先 → 缺失则按 hash 从云端下载 → 落沙盒缓存 → 返回字节。
/// - **上传**：算 hash → 写本地缓存 → 上传 CAS（按 hash 去重）→ 返回 `AttachmentRef`。
/// - **离线**：下载失败返回 null（由 UI 显示占位，联网后重试）。
///
/// 所有方法幂等、并发安全（写串行在 [VaultStorage] 内按路径保证）。
class AttachmentService {
  AttachmentService(this._api);

  final VaultApi _api;

  /// 读取本地缓存字节；不存在返回 null（不触发下载）。
  Future<Uint8List?> readCache(String hash, String ext) =>
      VaultStorage.readAttachmentBytes(hash, ext);

  /// 本地缓存是否存在。
  Future<bool> hasCache(String hash, String ext) =>
      VaultStorage.attachmentExists(hash, ext);

  /// 确保附件可用：本地有→直接返回；无→云端下载→写缓存→返回字节；失败返回 null。
  ///
  /// 用于 Markdown 图片懒拉取：渲染时调用，缺图时异步下载，成功后 UI 刷新。
  /// 重复并发请求同一 hash 由调用方去抖（UI 侧 widget 生命周期保证）。
  Future<Uint8List?> ensure(String hash, String ext) async {
    final cached = await VaultStorage.readAttachmentBytes(hash, ext);
    if (cached != null) return cached;
    final bytes = await _api.downloadAttachment(hash);
    if (bytes == null) return null;
    await VaultStorage.writeAttachmentBytes(hash, ext, bytes);
    return bytes;
  }

  /// 上传图片字节：算 hash → 写本地缓存 → 上传 CAS → 返回 [AttachmentRef]。
  ///
  /// 返回的 `relPath` 可直接插入 Markdown `![](<relPath>)`。
  /// 网络失败时仍写本地缓存（本地可见），返回带 hash/ext 的 ref（调用方可后续重传，
  /// 但阶段八移动端不实现持久化重传队列，那是阶段九）。
  Future<AttachmentRef> upload(Uint8List bytes, String ext) async {
    final hash = CryptoUtil.sha256BytesHex(bytes);
    // 先写本地缓存（本地立即可见，且作为上传字节源）。
    await VaultStorage.writeAttachmentBytes(hash, ext, bytes);
    // 上传 CAS（按 hash 去重）。
    final res = await _api.uploadAttachment(bytes, 'image.$ext');
    switch (res) {
      case ApiSuccess():
        // 服务端返回的 hash 应与本地一致（内容寻址）；以服务端为准兜底。
        return AttachmentRef(
          hash: res.data.hash,
          ext: ext,
          relPath: AttachmentRef.buildRelPath(res.data.hash, ext),
        );
      case ApiFailure():
        // 上传失败：本地缓存已写入，返回本地计算的 ref（relPath 仍可插入 Markdown，
        // 待联网后由阶段九离线队列或下次编辑重传）。
        return AttachmentRef(
          hash: hash,
          ext: ext,
          relPath: AttachmentRef.buildRelPath(hash, ext),
        );
    }
  }
}
