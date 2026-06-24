package com.lifescale.backend.user.invitecode.entity;

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
 * 邀请码（P0-7 注册加固）。code 为 URL 安全随机 token，核销后状态置 used 并回填使用者。
 */
@Entity
@Table(name = "ls_invite_code")
@EntityListeners(AuditingEntityListener.class)
public class InviteCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64, unique = true)
    private String code;

    @Column(name = "created_by_user_id", nullable = false)
    private long createdByUserId;

    @Column(name = "used_by_user_id")
    private Long usedByUserId;

    @Column(nullable = false, length = 20)
    private String status = "unused";

    @Column(name = "expires_at")
    private Instant expiresAt;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "used_at")
    private Instant usedAt;

    public InviteCode() {
    }

    public Long getId() { return id; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public long getCreatedByUserId() { return createdByUserId; }
    public void setCreatedByUserId(long createdByUserId) { this.createdByUserId = createdByUserId; }
    public Long getUsedByUserId() { return usedByUserId; }
    public void setUsedByUserId(Long usedByUserId) { this.usedByUserId = usedByUserId; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUsedAt() { return usedAt; }
    public void setUsedAt(Instant usedAt) { this.usedAt = usedAt; }
}
