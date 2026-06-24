package com.lifescale.backend.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifescale.backend.common.model.ApiResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;

/**
 * 接口限流（P0-9）：基于 Redis 固定窗口计数（INCR + 首次 EXPIRE）。
 * <p>
 * 设计：
 * - 注册在 {@link JwtAuthFilter} 之后，从而对受保护接口能用 {@link UserContext#getUserId()}
 *   作 key（同用户跨 IP 限流）；未登录（login/register/匿名）回退到客户端 IP。
 * - IP 取 X-Forwarded-For 首跳（生产部署在 Nginx 后），否则 remoteAddr。
 * - Redis 不可用时透明降级放行（与 DeviceCacheService 同模式），不阻塞主流程。
 * - 超限返回 429 + ApiResponse 信封 + Retry-After 头。
 * <p>
 * 路由规则（每分钟）：login 5/IP、register 3/IP、attachments 30/user、其他 /api/** 100/user(或IP)。
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    private static final Duration WINDOW = Duration.ofMinutes(1);
    private static final String KEY_PREFIX = "lifescale:rl:";

    private final RateLimitProperties props;
    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    public RateLimitFilter(RateLimitProperties props,
                           @Qualifier("redisTemplate") RedisTemplate<String, Object> redisTemplate,
                           ObjectMapper objectMapper) {
        this.props = props;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String path = request.getRequestURI();
        if (path == null || !path.startsWith("/api/")) {
            chain.doFilter(request, response);
            return;
        }
        if (!props.isEnabled()) {
            chain.doFilter(request, response);
            return;
        }

        Rule rule = resolveRule(path);
        if (rule == null) {
            chain.doFilter(request, response);
            return;
        }

        String subject = subjectFor(rule, request);
        String key = KEY_PREFIX + rule.bucket + ":" + subject;
        if (incrementAndCheck(key, rule.limit)) {
            chain.doFilter(request, response);
        } else {
            writeTooManyRequests(response, rule);
        }
    }

    /** Redis INCR；首次写入设 TTL（窗口计数）。Redis 异常 → 放行（降级）。 */
    private boolean incrementAndCheck(String key, int limit) {
        try {
            ValueOperations<String, Object> ops = redisTemplate.opsForValue();
            Long count = ops.increment(key);
            if (count != null && count == 1L) {
                redisTemplate.expire(key, WINDOW);
            }
            return count == null || count <= limit;
        } catch (Exception e) {
            log.warn("限流计数失败，降级放行：key={} err={}", key, e.getMessage());
            return true;
        }
    }

    /** 按 path 解析限流规则；非限流路径返回 null。 */
    private Rule resolveRule(String path) {
        if (path.startsWith("/api/auth/login")) {
            return new Rule("login", props.getLoginPerMinute(), false);
        }
        if (path.startsWith("/api/auth/register")) {
            return new Rule("register", props.getRegisterPerMinute(), false);
        }
        if (path.startsWith("/api/vault/attachments")) {
            return new Rule("attachment", props.getAttachmentPerMinute(), true);
        }
        // 默认：所有其他 /api/**
        return new Rule("default", props.getDefaultPerMinute(), true);
    }

    /** 优先 userId（已登录）；否则 IP。 */
    private String subjectFor(Rule rule, HttpServletRequest request) {
        if (rule.preferUser) {
            Long userId = UserContext.getUserId();
            if (userId != null) {
                return "u" + userId;
            }
        }
        return "ip:" + clientIp(request);
    }

    private String clientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        String remote = request.getRemoteAddr();
        return remote == null ? "unknown" : remote;
    }

    private void writeTooManyRequests(HttpServletResponse response, Rule rule) throws IOException {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
        response.setHeader(HttpHeaders.RETRY_AFTER, String.valueOf(WINDOW.toSeconds()));
        response.getWriter().write(objectMapper.writeValueAsString(
                ApiResponse.fail(429, "请求过于频繁，请稍后再试（" + rule.bucket + " 限流）")));
    }

    /** 内部规则描述：bucket（key 分组）、limit（每分钟）、preferUser（优先用 userId 作 subject）。 */
    private record Rule(String bucket, int limit, boolean preferUser) {
    }
}
