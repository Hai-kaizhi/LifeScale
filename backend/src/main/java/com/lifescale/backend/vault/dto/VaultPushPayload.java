package com.lifescale.backend.vault.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 推送一个 vault 文件。vaultPath 为相对路径，ifMatchHash 为客户端上次同步的服务端 hash（乐观锁）。
 */
public record VaultPushPayload(
        @NotBlank String vaultPath,
        String content,
        String ifMatchHash,
        String deviceId) {
}
