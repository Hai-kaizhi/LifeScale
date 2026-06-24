package com.lifescale.backend.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 设备注册/更新请求。deviceId 由客户端生成并稳定保存。
 */
public record DeviceRequest(
        @NotBlank @Size(max = 64) String deviceId,
        @Size(max = 100) String name,
        @Size(max = 20) String platform) {
}
