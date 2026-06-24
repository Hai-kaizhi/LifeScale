package com.lifescale.backend.vault.dto;

/** 冲突信息：服务端当前内容(theirs) + 冲突副本路径，供客户端冲突 UI 展示与解决。 */
public record ConflictView(
        String baseHash,
        String theirsHash,
        String theirsContent,
        String conflictCopyPath,
        Long conflictId) {
}
