package com.lifescale.backend.common.security;

import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 接口限流配置（P0-9）。绑定 lifescale.rate-limit.*。
 * <p>
 * 默认值与 application.yml 对齐：login 5/min/IP、register 3/min/IP、attachment 30/min/user、
 * 其他 /api/** 100/min。Redis 不可用时由 {@link RateLimitFilter} 降级放行。
 */
@Component
@ConfigurationProperties(prefix = "lifescale.rate-limit")
public class RateLimitProperties {

    private boolean enabled = true;
    @Min(1) private int loginPerMinute = 5;
    @Min(1) private int registerPerMinute = 3;
    @Min(1) private int attachmentPerMinute = 30;
    @Min(1) private int defaultPerMinute = 100;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public int getLoginPerMinute() { return loginPerMinute; }
    public void setLoginPerMinute(int loginPerMinute) { this.loginPerMinute = loginPerMinute; }
    public int getRegisterPerMinute() { return registerPerMinute; }
    public void setRegisterPerMinute(int registerPerMinute) { this.registerPerMinute = registerPerMinute; }
    public int getAttachmentPerMinute() { return attachmentPerMinute; }
    public void setAttachmentPerMinute(int attachmentPerMinute) { this.attachmentPerMinute = attachmentPerMinute; }
    public int getDefaultPerMinute() { return defaultPerMinute; }
    public void setDefaultPerMinute(int defaultPerMinute) { this.defaultPerMinute = defaultPerMinute; }
}
