package com.lifescale.backend.vault.dto;

/** 版本历史摘要。 */
public record VaultVersionSummary(
        int version,
        String contentHash,
        long size,
        String deviceId,
        String createdAt) {
}
