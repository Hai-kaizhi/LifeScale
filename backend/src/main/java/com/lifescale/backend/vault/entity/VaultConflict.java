package com.lifescale.backend.vault.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

/**
 * vault 冲突记录：无法自动合并时落一条，配合冲突副本文件保留双方内容。
 */
@Entity
@Table(name = "ls_vault_conflict")
@EntityListeners(AuditingEntityListener.class)
public class VaultConflict {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "vault_path", nullable = false, length = 500)
    private String vaultPath;

    @Column(name = "base_version")
    private Integer baseVersion;

    @Column(name = "mine_hash", length = 64)
    private String mineHash;

    @Column(name = "theirs_hash", length = 64)
    private String theirsHash;

    @Column(name = "merged_hash", length = 64)
    private String mergedHash;

    @Column(name = "conflict_copy_path", length = 500)
    private String conflictCopyPath;

    @Column(nullable = false, length = 20)
    private String status = "open";

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public VaultConflict() {
    }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getVaultPath() { return vaultPath; }
    public void setVaultPath(String vaultPath) { this.vaultPath = vaultPath; }
    public Integer getBaseVersion() { return baseVersion; }
    public void setBaseVersion(Integer baseVersion) { this.baseVersion = baseVersion; }
    public String getMineHash() { return mineHash; }
    public void setMineHash(String mineHash) { this.mineHash = mineHash; }
    public String getTheirsHash() { return theirsHash; }
    public void setTheirsHash(String theirsHash) { this.theirsHash = theirsHash; }
    public String getMergedHash() { return mergedHash; }
    public void setMergedHash(String mergedHash) { this.mergedHash = mergedHash; }
    public String getConflictCopyPath() { return conflictCopyPath; }
    public void setConflictCopyPath(String conflictCopyPath) { this.conflictCopyPath = conflictCopyPath; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
}
