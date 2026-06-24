package com.lifescale.backend.vault.dto;

import java.time.Instant;

/**
 * 冲突列表项（GET /api/vault/conflicts）：含双方内容预览，供移动端冲突中心页展示与处理。
 */
public record ConflictItem(
        Long conflictId,
        String vaultPath,
        String mineHash,
        String theirsHash,
        String theirsContent,
        String conflictCopyPath,
        String status,
        Instant createdAt) {
}
