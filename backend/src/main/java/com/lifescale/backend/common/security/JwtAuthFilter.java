package com.lifescale.backend.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.user.service.JwtService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * JWT 鉴权过滤器：从 Authorization: Bearer 解析 token，校验后将 userId 放入 {@link UserContext}。
 * <p>
 * 公开端点（免鉴权）：/api/auth/login、/api/auth/register、/api/health，以及所有非 /api/ 路径
 * （静态资源、swagger、actuator）。其余 /api/** 必须携带有效 token，否则返回 401（ApiResponse 格式）。
 * <p>
 * 注意：过滤器抛出的异常不经过 {@code @RestControllerAdvice}，因此 401 响应在此直接写出，
 * 以保持与全局 ApiResponse 信封一致。
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final ObjectMapper objectMapper;

    public JwtAuthFilter(JwtService jwtService, ObjectMapper objectMapper) {
        this.jwtService = jwtService;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        // 放行 CORS 预检（OPTIONS），避免跨域请求被 401 拦截。
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            chain.doFilter(request, response);
            return;
        }
        String path = request.getRequestURI();
        if (isPublic(path)) {
            chain.doFilter(request, response);
            return;
        }
        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            writeUnauthorized(response, "未登录或登录已过期");
            return;
        }
        try {
            String token = authHeader.substring(7).trim();
            Claims claims = jwtService.parse(token);
            UserContext.setUserId(Long.valueOf(claims.getSubject()));
            chain.doFilter(request, response);
        } catch (Exception e) {
            writeUnauthorized(response, "登录已失效，请重新登录");
        } finally {
            UserContext.clear();
        }
    }

    /** 公开端点判定：非 /api/ 全放行；/api/ 内仅放行 login/register/health。 */
    private boolean isPublic(String path) {
        if (path == null) {
            return true;
        }
        if (!path.startsWith("/api/")) {
            return true;
        }
        return path.startsWith("/api/auth/login")
                || path.startsWith("/api/auth/register")
                || path.startsWith("/api/health");
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(ApiResponse.fail(401, message)));
    }
}
