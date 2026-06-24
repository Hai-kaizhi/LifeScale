package com.lifescale.backend.profile.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

/**
 * 用户个人资料（展示型）：昵称 / 头像 / 问候语 / 每日提示。与 {@code ls_user} 1:1。
 * 仅存可由用户自行编辑的展示资料，账号与鉴权信息仍在 {@code ls_user}。
 */
@Entity
@Table(name = "ls_user_profile")
@EntityListeners(AuditingEntityListener.class)
public class UserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, unique = true)
    private Long userId;

    @Column(nullable = false, length = 64)
    private String nickname;

    @Column(name = "avatar_url", length = 512)
    private String avatarUrl;

    @Column(nullable = false, length = 100)
    private String greeting;

    @Column(name = "motivational_quote", nullable = false, length = 200)
    private String motivationalQuote;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public UserProfile() {
    }

    /** 以默认资料构造某用户的资料行。 */
    public static UserProfile withDefaults(Long userId, String nickname) {
        UserProfile p = new UserProfile();
        p.userId = userId;
        p.nickname = nickname == null || nickname.isBlank() ? "用户" : nickname;
        p.avatarUrl = null;
        p.greeting = DEFAULT_GREETING;
        p.motivationalQuote = DEFAULT_MOTIVATIONAL_QUOTE;
        return p;
    }

    public static final String DEFAULT_GREETING = "早安";
    public static final String DEFAULT_MOTIVATIONAL_QUOTE = "专注当下，重视行动，让每一天都成为进步的刻度。";

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
    public String getGreeting() { return greeting; }
    public void setGreeting(String greeting) { this.greeting = greeting; }
    public String getMotivationalQuote() { return motivationalQuote; }
    public void setMotivationalQuote(String motivationalQuote) { this.motivationalQuote = motivationalQuote; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
