package com.lifescale.backend.profile.dto;

import jakarta.validation.constraints.Size;

/**
 * 更新个人资料请求。所有字段可空，null 表示不更新该字段（部分更新）。
 */
public record UpdateProfileRequest(
        @Size(max = 64) String nickname,
        @Size(max = 512) String avatarUrl,
        @Size(max = 100) String greeting,
        @Size(max = 200) String motivationalQuote) {
}
