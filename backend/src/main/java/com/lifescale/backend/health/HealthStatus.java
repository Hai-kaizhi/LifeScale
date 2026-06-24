package com.lifescale.backend.health;

import java.time.Instant;

import io.swagger.v3.oas.annotations.media.Schema;

/** 健康检查响应对象，字段名保持稳定以便脚本和前端判断。 */
@Schema(description = "健康检查响应")
public record HealthStatus(
        @Schema(description = "机器可读状态，UP 表示服务可用。", example = "UP")
        String status,

        @Schema(description = "服务中文名称。", example = "LifeScale 后端服务")
        String application,

        @Schema(description = "服务端生成响应的 UTC 时间。", example = "2026-06-12T08:00:00Z")
        Instant timestamp) {
}
