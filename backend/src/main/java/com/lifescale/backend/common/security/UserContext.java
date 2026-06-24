package com.lifescale.backend.common.security;

/**
 * 当前请求的用户上下文（ThreadLocal），由 {@link JwtAuthFilter} 在请求开始时填充、结束时清理。
 * 业务服务通过 {@link #requireUserId()} 取当前登录用户 id。
 */
public final class UserContext {

    private static final ThreadLocal<Long> USER_ID = new ThreadLocal<>();

    private UserContext() {
    }

    public static void setUserId(Long userId) {
        USER_ID.set(userId);
    }

    public static Long getUserId() {
        return USER_ID.get();
    }

    /** 取当前用户 id；未登录则抛 {@link UnauthorizedException}。 */
    public static Long requireUserId() {
        Long userId = USER_ID.get();
        if (userId == null) {
            throw new UnauthorizedException("未登录或登录已过期");
        }
        return userId;
    }

    public static void clear() {
        USER_ID.remove();
    }
}
