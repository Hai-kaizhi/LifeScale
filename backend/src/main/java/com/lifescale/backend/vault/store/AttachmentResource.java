package com.lifescale.backend.vault.store;

import java.io.InputStream;
import java.nio.file.Path;
import java.util.Optional;
import java.util.function.Supplier;

/**
 * 附件下载的统一资源描述（能力式接口，P0-10 重构）。
 * <p>
 * 取代旧的 {@code Optional<Path> attachmentLocation(hash)} 方案，避免 Controller 用
 * {@code instanceof} 区分磁盘/COS。两种后端各自构造本对象：
 * <ul>
 *   <li>磁盘 CAS：filePath 存在 → Controller 包 {@code FileSystemResource}，Spring 自动支持 Range/206。</li>
 *   <li>腾讯云 COS：filePath 为空、提供 streamSupplier + size → Controller 包 {@code InputStreamResource}。</li>
 * </ul>
 *
 * @param size           附件字节数（Content-Length）
 * @param filePath       本地文件路径（磁盘 CAS）；COS 为空
 * @param streamSupplier 输入流供应器（COS 流式下载用）；磁盘可空（用 filePath 即可）
 */
public record AttachmentResource(long size,
                                 Optional<Path> filePath,
                                 Supplier<InputStream> streamSupplier) {

    /** 磁盘 CAS 构造：filePath 必填，stream 留空。 */
    public static AttachmentResource ofFile(long size, Path filePath) {
        return new AttachmentResource(size, Optional.of(filePath), null);
    }

    /** COS 构造：stream + size，filePath 为空。 */
    public static AttachmentResource ofStream(long size, Supplier<InputStream> streamSupplier) {
        return new AttachmentResource(size, Optional.empty(), streamSupplier);
    }
}
