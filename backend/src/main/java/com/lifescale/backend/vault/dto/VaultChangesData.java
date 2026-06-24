package com.lifescale.backend.vault.dto;

import java.util.List;

/** /api/vault/changes 返回：变更摘要列表 + 游标。 */
public record VaultChangesData(
        List<VaultChangeSummary> changes,
        String serverTime,
        String nextCursor,
        boolean hasMore) {
}
