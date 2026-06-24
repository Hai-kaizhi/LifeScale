package com.lifescale.backend.common.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * 内容哈希工具：SHA-256 十六进制摘要，用于多端冲突识别（乐观锁）。
 *
 * <p>历史位于 {@code document/service/}，因属于纯静态工具（无 Spring 依赖、无 DB 依赖），
 * 迁移到 {@code common/util/} 供 vault/sync 等模块复用。原 Model B 的 document 包已删除。
 */
public final class ContentHasher {

    private ContentHasher() {
    }

    public static String sha256(String content) {
        String input = content == null ? "" : content;
        return sha256(input.getBytes(StandardCharsets.UTF_8));
    }

    /** 字节级 SHA-256（附件内容寻址）。 */
    public static String sha256(byte[] bytes) {
        byte[] input = bytes == null ? new byte[0] : bytes;
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input);
            StringBuilder hex = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            return null;
        }
    }
}
