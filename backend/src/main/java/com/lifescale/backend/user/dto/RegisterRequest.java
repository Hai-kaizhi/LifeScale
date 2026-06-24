package com.lifescale.backend.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 注册请求。
 *
 * @param username   用户名
 * @param password   密码（P0-8 强度要求：≥8 位 + 字母与数字，业务层 PasswordPolicy 复核）
 * @param email      邮箱（可选）
 * @param inviteCode 邀请码（P0-7：lifescale.auth.invite-code.enabled=true 时必填，否则忽略）
 */
public record RegisterRequest(
        @NotBlank String username,
        @NotBlank @Size(min = 8, max = 64) String password,
        @Email String email,
        String inviteCode) {
}
