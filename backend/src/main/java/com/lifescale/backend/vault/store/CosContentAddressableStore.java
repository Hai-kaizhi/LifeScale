package com.lifescale.backend.vault.store;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.model.COSObject;
import com.qcloud.cos.model.GetObjectRequest;
import com.qcloud.cos.model.ObjectMetadata;
import com.qcloud.cos.model.PutObjectRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Optional;

/**
 * 腾讯云 COS 附件 CAS（混合方案，P0-10）：Markdown 正文委托磁盘 CAS，附件字节存 COS。
 * <p>
 * 装配条件：lifescale.storage.cos.bucket 非空。此时本类以 @Primary 注入到 VaultService /
 * AttachmentController；正文方法委托 {@link FileSystemContentAddressableStore}（始终装配），
 * 附件方法走 COS。本地不配 bucket → 本类不装配 → 直接用磁盘 CAS，零侵入。
 * <p>
 * 与 {@link S3ContentAddressableStore} 的关系：S3 是 MinIO/S3 兼容 seam（空实现，不加 @Component），
 * 本类是腾讯云 COS 专用实现。COS SDK 兼容 S3 协议，未来如需 MinIO 可基于本类改造。
 */
@Component
@Primary
@ConditionalOnProperty(prefix = "lifescale.storage.cos", name = "bucket")
public class CosContentAddressableStore implements ContentAddressableStore {

    private static final Logger log = LoggerFactory.getLogger(CosContentAddressableStore.class);

    private final COSClient cosClient;
    private final String bucket;
    private final String prefix;
    private final FileSystemContentAddressableStore fsCas; // 正文委托

    public CosContentAddressableStore(COSClient cosClient,
                                      @Value("${lifescale.storage.cos.bucket}") String bucket,
                                      @Value("${lifescale.storage.cos.prefix:att}") String prefix,
                                      FileSystemContentAddressableStore fsCas) {
        this.cosClient = cosClient;
        this.bucket = bucket;
        this.prefix = prefix;
        this.fsCas = fsCas;
        log.info("COS 附件 CAS 已启用：bucket={}, prefix={}", bucket, prefix);
    }

    // ============================ 正文（委托磁盘 CAS）============================

    @Override
    public String storeText(String content) {
        return fsCas.storeText(content);
    }

    @Override
    public void store(String hash, byte[] content) {
        fsCas.store(hash, content);
    }

    @Override
    public byte[] read(String hash) {
        return fsCas.read(hash);
    }

    @Override
    public String readText(String hash) {
        return fsCas.readText(hash);
    }

    @Override
    public boolean exists(String hash) {
        return fsCas.exists(hash);
    }

    // ============================ 附件（走 COS）============================

    @Override
    public void storeAttachment(String hash, byte[] bytes) {
        String key = cosKey(hash);
        try {
            // CAS 语义：已存在则跳过（doesObjectExist 一次 HEAD 请求）
            if (cosClient.doesObjectExist(bucket, key)) {
                return;
            }
            ObjectMetadata meta = new ObjectMetadata();
            meta.setContentLength(bytes.length);
            meta.setContentType("application/octet-stream");
            ByteArrayInputStream input = new ByteArrayInputStream(bytes);
            cosClient.putObject(new PutObjectRequest(bucket, key, input, meta));
        } catch (Exception e) {
            throw new RuntimeException("COS 附件写入失败: " + hash, e);
        }
    }

    @Override
    public byte[] readAttachment(String hash) {
        String key = cosKey(hash);
        try (COSObject obj = cosClient.getObject(new GetObjectRequest(bucket, key));
             InputStream is = obj.getObjectContent()) {
            return is.readAllBytes();
        } catch (Exception e) {
            log.warn("COS 附件读取失败：hash={}, err={}", hash, e.getMessage());
            return null;
        }
    }

    @Override
    public boolean existsAttachment(String hash) {
        try {
            return cosClient.doesObjectExist(bucket, cosKey(hash));
        } catch (Exception e) {
            log.warn("COS 附件存在性检查失败：hash={}, err={}", hash, e.getMessage());
            return false;
        }
    }

    /**
     * 附件下载资源（COS）：返回 stream + size（filePath 为空，故不启用 Range/206，符合 MVP 图片场景）。
     * 如未来需断点续传，可用 COS SDK GetObjectRequest.setRange 并返回 206。
     */
    @Override
    public Optional<AttachmentResource> attachmentResource(String hash) {
        if (hash == null) {
            return Optional.empty();
        }
        String key = cosKey(hash);
        long size = cosClient.getObjectMetadata(bucket, key).getContentLength();
        return Optional.of(AttachmentResource.ofStream(size,
                () -> cosClient.getObject(new GetObjectRequest(bucket, key)).getObjectContent()));
    }

    @Override
    public String storageLocationTag() {
        return "cos";
    }

    private String cosKey(String hash) {
        String prefix2 = hash.length() >= 2 ? hash.substring(0, 2) : "00";
        return prefix + "/" + prefix2 + "/" + hash;
    }
}
