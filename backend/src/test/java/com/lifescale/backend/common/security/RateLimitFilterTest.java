package com.lifescale.backend.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * 限流过滤器单测（P0-9）：覆盖计数放行、超限 429、Redis 宕机降级、规则路由。
 */
class RateLimitFilterTest {

    private RateLimitProperties props;
    private RedisTemplate<String, Object> redisTemplate;
    private ValueOperations<String, Object> valueOps;
    private RateLimitFilter filter;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        props = new RateLimitProperties();
        props.setEnabled(true);
        props.setLoginPerMinute(5);
        redisTemplate = mock(RedisTemplate.class);
        valueOps = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        filter = new RateLimitFilter(props, redisTemplate, new ObjectMapper());
    }

    @AfterEach
    void clear() {
        UserContext.clear();
    }

    @Test
    @DisplayName("非 /api/ 路径直接放行（200）")
    void nonApiPathBypasses() throws Exception {
        MockHttpServletRequest req = request("GET", "/swagger-ui.html");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("login 计数未超：放行（200）")
    void loginUnderLimitAllowed() throws Exception {
        when(valueOps.increment(anyString())).thenReturn(3L);
        MockHttpServletRequest req = request("POST", "/api/auth/login");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("login 超限：429 + Retry-After")
    void loginOverLimitReturns429() throws Exception {
        when(valueOps.increment(anyString())).thenReturn(6L); // 超过 5
        MockHttpServletRequest req = request("POST", "/api/auth/login");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(429);
        assertThat(res.getHeader("Retry-After")).isEqualTo("60");
        assertThat(res.getContentAsString()).contains("请求过于频繁");
    }

    @Test
    @DisplayName("已登录用户：限流 key 用 userId（跨 IP 统一计数）")
    void authenticatedUserKeyedByUserId() throws Exception {
        UserContext.setUserId(42L);
        when(valueOps.increment(eq("lifescale:rl:default:u42"))).thenReturn(10L);
        MockHttpServletRequest req = request("GET", "/api/vault/changes");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("未登录匿名请求：限流 key 用 IP（取 X-Forwarded-For 首跳）")
    void anonymousKeyedByForwardedIp() throws Exception {
        when(valueOps.increment(eq("lifescale:rl:register:ip:203.0.113.9"))).thenReturn(1L);
        MockHttpServletRequest req = request("POST", "/api/auth/register");
        req.addHeader("X-Forwarded-For", "203.0.113.9, 10.0.0.1");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("Redis 宕机：降级放行（不阻塞主流程）")
    void redisFailureDegradesToAllow() throws Exception {
        when(valueOps.increment(anyString())).thenThrow(new RuntimeException("redis down"));
        MockHttpServletRequest req = request("POST", "/api/auth/login");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("enabled=false：直接放行，不查 Redis")
    void disabledBypasses() throws Exception {
        props.setEnabled(false);
        MockHttpServletRequest req = request("POST", "/api/auth/login");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isEqualTo(200);
    }

    private MockHttpServletRequest request(String method, String uri) {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        req.setRemoteAddr("127.0.0.1");
        return req;
    }
}
