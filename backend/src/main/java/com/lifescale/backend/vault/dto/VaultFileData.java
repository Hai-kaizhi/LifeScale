package com.lifescale.backend.vault.dto;

/** 单个 vault 文件正文 + 元信息。 */
public record VaultFileData(
        String vaultPath,
        String content,
        String contentHash,
        int version,
        String serverMtime,
        long size) {
}
