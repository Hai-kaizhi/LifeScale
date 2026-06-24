package com.lifescale.backend.user.dto;

/**
 * 设备信息（列表/注册返回）。
 */
public record DeviceDTO(
        Long id,
        String deviceId,
        String name,
        String platform,
        String lastSyncedAt,
        String lastSeenAt) {
}
