package com.lifescale.backend.vault.store;

import java.util.Optional;

/**
 * 内容寻址存储（CAS）：按 SHA-256 存取正文，天然去重；Markdown 与（后续）附件共用。
 * <p>
 * 实现：
 * <ul>
 *   <li>{@link FileSystemContentAddressableStore}：磁盘 CAS（Markdown 正文 + 附件），始终装配。</li>
 *   <li>{@link CosContentAddressableStore}：腾讯云 COS（附件专用，混合方案），配置 bucket 时 @Primary 装配。</li>
 *   <li>{@link S3ContentAddressableStore}：S3/MinIO 兼容 seam（空实现，保留作迁移参考，不加 @Component）。</li>
 * </ul>
 */
public interface ContentAddressableStore {

    /** 存原始字节（按 hash）。已存在则跳过（去重）。 */
    void store(String hash, byte[] content);

    /** 存文本：算 hash、存正文、返回 hash。 */
    String storeText(String content);

    /** 按 hash 读字节；缺失返回 null。 */
    byte[] read(String hash);

    /** 按 hash 读文本；缺失返回 null。 */
    String readText(String hash);

    boolean exists(String hash);

    // ---- 附件（内容寻址 blob，隔离 att/ 子树，无 .md 后缀）----

    /** 存附件字节（按 hash）。已存在则跳过（去重）。 */
    void storeAttachment(String hash, byte[] content);

    /** 按 hash 读附件字节；缺失返回 null。 */
    byte[] readAttachment(String hash);

    boolean existsAttachment(String hash);

    /**
     * 附件下载资源（能力式，P0-10）：磁盘返回 filePath（启用 Range/206），COS 返回 stream + size。
     * 调用方无需 instanceof 区分后端。附件不存在时返回 empty。
     * <p>本方法不做存在性校验；调用方应先用 {@link #existsAttachment} 判定。
     */
    Optional<AttachmentResource> attachmentResource(String hash);

    /**
     * 存储位置标签：磁盘 CAS 返回 "local"，腾讯云 COS 返回 "cos"。
     * 用于 {@code ls_attachment.storage_location} 元数据写入（混合方案迁移追踪）。
     */
    String storageLocationTag();
}
