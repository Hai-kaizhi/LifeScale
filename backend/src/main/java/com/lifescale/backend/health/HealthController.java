package com.lifescale.backend.health;

import java.time.Instant;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 提供后端服务可用性检查接口。 */
@RestController
@RequestMapping("/api/health")
@Tag(name = "健康检查", description = "用于确认 LifeScale 后端服务是否可用。")
public class HealthController {

    /** 返回最小可用状态，供启动脚本、桌面端和 OpenAPI 验收使用。 */
    @GetMapping
    @Operation(summary = "检查后端服务状态", description = "返回后端服务的机器可读状态、服务名称和当前时间。")
    @ApiResponse(
            responseCode = "200",
            description = "后端服务可用",
            content = @Content(schema = @Schema(implementation = HealthStatus.class)))
    public HealthStatus health() {
        return new HealthStatus("UP", "LifeScale 后端服务", Instant.now());
    }
}
