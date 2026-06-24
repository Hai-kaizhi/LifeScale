package com.lifescale.backend.user.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.Date;

/**
 * JWT 签发与解析（HS256）。subject 为 userId，附带 username / deviceId。
 */
@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    private static final int MIN_SECRET_BYTES = 32;
    private static final String KNOWN_WEAK_SECRET =
            "lifescale-local-dev-jwt-secret-please-change-in-production-at-least-32-bytes";

    private final SecretKey key;
    private final long ttlMillis;

    public JwtService(@Value("${lifescale.auth.jwt-secret}") String secret,
                      @Value("${lifescale.auth.jwt-ttl-hours:168}") long ttlHours,
                      Environment environment) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.ttlMillis = Duration.ofHours(ttlHours).toMillis();
        // P0-5：启动期校验密钥强度，生产 profile 下空值/已知弱默认 → fail-fast。
        validateSecretAtConstruction(secret, environment);
    }

    /**
     * 生产加固：HS256 要求密钥 ≥32 字节；prod profile 下若密钥为空或仍是已知弱默认值，启动直接失败，
     * 杜绝「误用 local 默认值上生产 → token 可被离线伪造」。
     */
    private void validateSecretAtConstruction(String secret, Environment environment) {
        boolean isProd = environment != null
                && Arrays.asList(environment.getActiveProfiles()).contains("prod");
        if (secret == null || secret.isBlank() || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            if (isProd) {
                throw new IllegalStateException(
                        "LIFESCALE_JWT_SECRET 在生产环境无效（空或 <32 字节）。请用 `openssl rand -base64 48` 生成强随机值并注入。");
            }
            log.warn("LIFESCALE_JWT_SECRET 为空或不足 32 字节，仅适合本地开发，生产必须更换。");
        }
        if (KNOWN_WEAK_SECRET.equals(secret) && isProd) {
            throw new IllegalStateException(
                    "LIFESCALE_JWT_SECRET 在生产环境仍为已知弱默认值。请用 `openssl rand -base64 48` 生成强随机值并注入。");
        }
    }

    @PostConstruct
    void logTtl() {
        log.info("JwtService 已就绪：TTL={}h", Duration.ofMillis(ttlMillis).toHours());
    }

    public IssuedToken issue(Long userId, String username, String deviceId) {
        Instant now = Instant.now();
        Instant exp = now.plusMillis(ttlMillis);
        String token = Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("username", username)
                .claim("deviceId", deviceId)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(key)
                .compact();
        return new IssuedToken(token, exp);
    }

    public Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public record IssuedToken(String token, Instant expiresAt) {
    }
}
