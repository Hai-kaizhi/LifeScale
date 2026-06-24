package com.lifescale.backend.profile.dto;

/**
 * 用户个人资料（展示型），与前端 UserProfile 类型对齐。
 */
public record UserProfileDTO(
        String nickname,
        String avatarUrl,
        String greeting,
        String motivationalQuote) {
}
