package com.lifescale.backend.user.dto;

/**
 * 登录/注册成功后返回的会话（含 JWT）。
 */
public record AuthSession(
        Long userId,
        String username,
        String email,
        String token,
        String expiresAt) {
}
