package com.lifescale.backend.vault.dto;

/** 增量变更摘要（不含正文），客户端按 version/hash 决定是否拉取正文；status=deleted 表示删除事件。 */
public record VaultChangeSummary(
        String vaultPath,
        String contentHash,
        int version,
        String serverMtime,
        String status,
        long size) {
}
