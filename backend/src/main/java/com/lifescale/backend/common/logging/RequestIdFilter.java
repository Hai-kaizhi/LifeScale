package com.lifescale.backend.common.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * 请求 ID 过滤器：为每个 HTTP 请求注入 requestId 到 MDC，串联同一请求的全部日志。
 * <p>
 * 优先透传上游请求头 {@code X-Request-Id}（便于跨服务链路追踪），无则生成 8 位短码。
 * 通过 {@code finally} 清理 MDC，避免线程池复用导致的上下文泄漏。
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    public static final String MDC_REQUEST_ID = "requestId";
    public static final String HEADER_REQUEST_ID = "X-Request-Id";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        // 优先透传上游 requestId，无则生成短码
        String requestId = request.getHeader(HEADER_REQUEST_ID);
        if (requestId == null || requestId.isBlank()) {
            requestId = generateShortId();
        }
        MDC.put(MDC_REQUEST_ID, requestId);
        // 回写响应头，前端/网关可记录，便于联调
        response.setHeader(HEADER_REQUEST_ID, requestId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            // 必须清理，否则线程池复用时会污染下一个请求的日志上下文
            MDC.remove(MDC_REQUEST_ID);
        }
    }

    /**
     * 生成 8 位短码（UUID 前 8 位），兼顾可读性与唯一性。
     */
    private static String generateShortId() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 8);
    }
}
