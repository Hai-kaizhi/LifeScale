package com.lifescale.backend.vault.attachment;

/**
 * 附件上传结果：内容 hash（SHA-256，身份）、字节大小、vault 内引用路径（不含扩展名，由客户端按类型补）。
 */
public record AttachmentUploadResult(String hash, long size, String path) {
}
