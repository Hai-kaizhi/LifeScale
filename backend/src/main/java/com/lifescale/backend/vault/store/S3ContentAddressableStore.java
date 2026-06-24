package com.lifescale.backend.vault.store;

import java.util.Optional;

/**
 * S3/MinIO 兼容 CAS seam —— 已被 {@link CosContentAddressableStore}（腾讯云 COS 专用）取代。
 * <p>
 * 保留作 MinIO/S3 协议迁移的文档化参考（COS SDK 兼容 S3 协议，未来如需 MinIO 可基于
 * {@code CosContentAddressableStore} 改造）。当前**不加 {@code @Component}**，不会被装配，
 * 方法一律抛 {@link UnsupportedOperationException}。新接口契约已对齐（{@link #attachmentResource}
 * / {@link #storageLocationTag}），以保证编译期类型一致。
 */
public class S3ContentAddressableStore implements ContentAddressableStore {

    @Override
    public void store(String hash, byte[] content) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public String storeText(String content) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public byte[] read(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public String readText(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public boolean exists(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public void storeAttachment(String hash, byte[] content) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public byte[] readAttachment(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public boolean existsAttachment(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public Optional<AttachmentResource> attachmentResource(String hash) {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }

    @Override
    public String storageLocationTag() {
        throw new UnsupportedOperationException("S3/MinIO CAS seam，已被 CosContentAddressableStore 取代");
    }
}
