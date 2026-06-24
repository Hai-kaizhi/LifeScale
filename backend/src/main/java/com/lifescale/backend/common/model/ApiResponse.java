package com.lifescale.backend.common.model;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * 通用 API 响应包装，与前端 ApiResponse&lt;T&gt; 类型对齐。
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record ApiResponse<T>(
        int code,
        boolean success,
        String message,
        T data) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(200, true, "ok", data);
    }

    public static <T> ApiResponse<T> ok() {
        return new ApiResponse<>(200, true, "ok", null);
    }

    public static <T> ApiResponse<T> fail(String message) {
        return new ApiResponse<>(500, false, message, null);
    }

    public static <T> ApiResponse<T> fail(int code, String message) {
        return new ApiResponse<>(code, false, message, null);
    }

    public static <T> ApiResponse<T> fail(int code, String message, T data) {
        return new ApiResponse<>(code, false, message, data);
    }
}
