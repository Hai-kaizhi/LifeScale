package com.lifescale.backend.common.security;

/**
 * 鉴权失败异常：未登录、token 无效或账号已禁用。映射为 HTTP 401。
 */
public class UnauthorizedException extends RuntimeException {

    public UnauthorizedException(String message) {
        super(message);
    }
}
