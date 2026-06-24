package com.lifescale.backend.health;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class HealthControllerTest {

    @Test
    @DisplayName("健康检查接口应返回第 0 步工程底座状态")
    void healthReturnsFoundationStatus() {
        // 直接调用控制器，确保启动脚本和 OpenAPI 依赖的字段值保持稳定。
        HealthStatus status = new HealthController().health();

        assertThat(status.status()).isEqualTo("UP");
        assertThat(status.application()).isEqualTo("LifeScale 后端服务");
        assertThat(status.timestamp()).isNotNull();
    }
}
