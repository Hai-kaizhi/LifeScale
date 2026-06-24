package com.lifescale.backend.common.logging;

import jakarta.servlet.http.HttpServletRequest;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Arrays;
import java.util.List;

/**
 * 全局请求日志切面：环绕所有 {@code @RestController} 方法，记录请求入参、耗时与异常。
 * <p>
 * 配合 {@link RequestIdFilter} 的 MDC requestId，可在日志中串联同一请求的完整链路。
 * <ul>
 *   <li>正常请求：INFO，含 HTTP 方法、URI、方法签名、入参摘要、耗时</li>
 *   <li>慢请求（&gt;500ms）：WARN 提示</li>
 *   <li>异常请求：ERROR 记录异常类型与消息，异常重新抛出交由 GlobalExceptionHandler 处理</li>
 * </ul>
 */
@Aspect
@Component
public class RequestLoggingAspect {

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingAspect.class);

    /** 慢请求阈值（毫秒），超过则提升日志级别为 WARN */
    private static final long SLOW_REQUEST_THRESHOLD_MS = 500;

    /** actuator 健康检查等无需详细记录的路径前缀 */
    private static final List<String> SKIPPED_PATH_PREFIXES = List.of("/actuator", "/swagger-ui", "/v3/api-docs");

    /**
     * 环绕所有 @RestController 的公共方法。
     */
    @Around("within(@org.springframework.web.bind.annotation.RestController *)")
    public Object logAround(ProceedingJoinPoint joinPoint) throws Throwable {
        HttpServletRequest request = currentRequest();

        // actuator / swagger 等噪音路径跳过详细日志
        if (shouldSkip(request)) {
            return joinPoint.proceed();
        }

        String methodSignature = joinPoint.getSignature().toShortString();
        String argsSummary = summarizeArgs(joinPoint.getArgs());

        // 入口日志：HTTP 方法、URI、控制器方法、入参
        if (request != null) {
            log.info("[REQ] {} {} -> {} args={}",
                    request.getMethod(),
                    request.getRequestURI(),
                    methodSignature,
                    argsSummary);
        } else {
            log.info("[REQ] {} args={}", methodSignature, argsSummary);
        }

        long startNanos = System.nanoTime();
        try {
            Object result = joinPoint.proceed();
            long elapsedMs = (System.nanoTime() - startNanos) / 1_000_000;

            // 出口日志：耗时 + 返回值类型（不打印返回值内容，避免大对象污染日志）
            if (elapsedMs > SLOW_REQUEST_THRESHOLD_MS) {
                log.warn("[RES] {} completed in {}ms (SLOW), returns {}",
                        methodSignature, elapsedMs, typeName(result));
            } else {
                log.info("[RES] {} completed in {}ms, returns {}",
                        methodSignature, elapsedMs, typeName(result));
            }
            return result;
        } catch (Throwable ex) {
            long elapsedMs = (System.nanoTime() - startNanos) / 1_000_000;
            // 异常日志：记录异常类型、消息、耗时；完整堆栈交由 GlobalExceptionHandler 记录，此处不重复打印
            log.error("[RES] {} failed in {}ms: {}: {}",
                    methodSignature, elapsedMs, ex.getClass().getSimpleName(), ex.getMessage());
            throw ex;
        }
    }

    /**
     * 安全获取当前 HTTP 请求，非 Web 线程（如异步任务）返回 null。
     */
    private HttpServletRequest currentRequest() {
        ServletRequestAttributes attrs =
                (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        return attrs == null ? null : attrs.getRequest();
    }

    /**
     * 判断是否跳过日志（健康检查、文档路径）。
     */
    private boolean shouldSkip(HttpServletRequest request) {
        if (request == null) {
            return false;
        }
        String uri = request.getRequestURI();
        return SKIPPED_PATH_PREFIXES.stream().anyMatch(uri::startsWith);
    }

    /**
     * 入参摘要：限制条数与长度，避免超大参数（如文件流）污染日志。
     */
    private String summarizeArgs(Object[] args) {
        if (args == null || args.length == 0) {
            return "[]";
        }
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < args.length; i++) {
            if (i > 0) {
                sb.append(", ");
            }
            Object arg = args[i];
            if (arg == null) {
                sb.append("null");
            } else {
                String str = arg.toString();
                // 单参数截断到 200 字符，防止巨型 body 刷屏
                if (str.length() > 200) {
                    sb.append(str, 0, 200).append("...(truncated)");
                } else {
                    sb.append(str);
                }
            }
        }
        sb.append("]");
        return sb.toString();
    }

    /**
     * 返回值类型名（避免打印返回值内容，仅记类型）。
     */
    private String typeName(Object result) {
        return result == null ? "void/null" : result.getClass().getSimpleName();
    }
}
