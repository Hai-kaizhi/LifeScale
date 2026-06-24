package com.lifescale.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

/**
 * AOP 配置：启用 AspectJ 自动代理，使 RequestLoggingAspect 等切面生效。
 * proxyTargetClass=true 使用 CGLIB 代理（兼容无接口的类，Spring Boot 默认推荐）。
 */
@Configuration
@EnableAspectJAutoProxy(proxyTargetClass = true)
public class LoggingConfig {
}
