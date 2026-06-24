package com.lifescale.backend.vault.attachment.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

/**
 * 附件内容寻址元数据：SHA-256 为主键（与 CAS 存储路径对齐：att/&lt;hash前2位&gt;/&lt;hash&gt;）。
 * 正文不在本表，落在 CAS。owner 为首次上传者，ref_count / last_used_at 供后续孤儿清理（GC）。
 */
@Entity
@Table(name = "ls_attachment")
public class Attachment {

    @Id
    @Column(name = "sha256", nullable = false, length = 64)
    private String sha256;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @Column(name = "owner_user_id", nullable = false)
    private long ownerUserId;

    @Column(name = "ref_count", nullable = false)
    private int refCount = 1;

    /**
     * 存储位置标记（P0-10）：local=磁盘CAS / cos=腾讯云COS。
     * 由当前注入的 CAS 实现的 storageLocationTag() 写入，用于混合方案迁移追踪。
     */
    @Column(name = "storage_location", nullable = false, length = 8)
    private String storageLocation = "local";

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "last_used_at", nullable = false)
    private Instant lastUsedAt = Instant.now();

    public Attachment() {
    }

    public String getSha256() { return sha256; }
    public void setSha256(String sha256) { this.sha256 = sha256; }

    public long getSizeBytes() { return sizeBytes; }
    public void setSizeBytes(long sizeBytes) { this.sizeBytes = sizeBytes; }

    public long getOwnerUserId() { return ownerUserId; }
    public void setOwnerUserId(long ownerUserId) { this.ownerUserId = ownerUserId; }

    public int getRefCount() { return refCount; }
    public void setRefCount(int refCount) { this.refCount = refCount; }

    public String getStorageLocation() { return storageLocation; }
    public void setStorageLocation(String storageLocation) { this.storageLocation = storageLocation; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getLastUsedAt() { return lastUsedAt; }
    public void setLastUsedAt(Instant lastUsedAt) { this.lastUsedAt = lastUsedAt; }
}
