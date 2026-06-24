package com.lifescale.backend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifescale.backend.common.security.JwtAuthFilter;
import com.lifescale.backend.common.security.RateLimitFilter;
import com.lifescale.backend.common.security.RateLimitProperties;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.data.redis.core.RedisTemplate;

/**
 * 限流过滤器装配（P0-9）。
 * <p>
 * 注册顺序：必须在 {@link JwtAuthFilter} 之后执行，这样受保护接口的 {@code UserContext}
 * 已被填充，限流 key 才能用 userId（跨 IP 同用户统一计数）。JwtAuthFilter 作为 @Component
 * 自动注册（默认 Order 接近最高优先级），这里把 RateLimitFilter 顺序排在其后。
 */
@Configuration
public class RateLimitConfig {

    /**
     * 用 FilterRegistrationBean 控制顺序。JwtAuthFilter（@Component）默认 order 为
     * Ordered.HIGHEST_PRECEDENCE + 50；这里取 + 60 保证在其之后。
     */
    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilterRegistration(
            RateLimitProperties props,
            @Qualifier("redisTemplate") RedisTemplate<String, Object> redisTemplate,
            ObjectMapper objectMapper) {
        FilterRegistrationBean<RateLimitFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new RateLimitFilter(props, redisTemplate, objectMapper));
        registration.addUrlPatterns("/api/*");
        registration.setName("rateLimitFilter");
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 60);
        return registration;
    }
}
