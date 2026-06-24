package com.lifescale.backend.vault.attachment;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.common.util.ContentHasher;
import com.lifescale.backend.vault.attachment.entity.Attachment;
import com.lifescale.backend.vault.attachment.repository.AttachmentRepository;
import com.lifescale.backend.vault.store.AttachmentResource;
import com.lifescale.backend.vault.store.ContentAddressableStore;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Instant;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Vault 附件同步接口（内容寻址）：POST 上传按 SHA-256 去重存 CAS；GET 按 hash 流式下载。
 * 附件按 hash 全局去重、永不冲突；需登录（JWT）。
 * <p>
 * GET 为首个二进制流端点（不经 ApiResponse 包装）。P0-10 重构后通过 {@link AttachmentResource}
 * 能力式描述统一处理磁盘/COS 两种后端，无需 {@code instanceof}：
 * <ul>
 *   <li>filePath 存在 → {@link FileSystemResource}，Spring 自动支持 Range/206（磁盘 CAS）。</li>
 *   <li>filePath 为空、有 streamSupplier → {@link InputStreamResource}（腾讯云 COS）。</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/vault/attachments")
@Tag(name = "Vault 附件同步", description = "内容寻址（SHA-256）附件上传/下载，永不冲突、按需懒拉取")
public class AttachmentController {

    private static final Logger log = LoggerFactory.getLogger(AttachmentController.class);
    private static final Pattern HASH_RE = Pattern.compile("[0-9a-f]{64}");

    private final ContentAddressableStore cas;
    private final AttachmentRepository attachmentRepository;

    public AttachmentController(ContentAddressableStore cas, AttachmentRepository attachmentRepository) {
        this.cas = cas;
        this.attachmentRepository = attachmentRepository;
    }

    @PostMapping
    @Operation(summary = "上传附件（按内容 hash 去重）",
            description = "接收字节 → 算 SHA-256 → CAS 存储（已存在则跳过）→ 落 ls_attachment 元数据（含 storage_location）→ 返回 hash/size/path")
    @Transactional
    public ApiResponse<AttachmentUploadResult> upload(@RequestParam("file") MultipartFile file) throws IOException {
        Long userId = UserContext.requireUserId();
        byte[] bytes = file.getBytes();
        String hash = ContentHasher.sha256(bytes);
        if (hash == null) {
            return ApiResponse.fail(500, "附件哈希计算失败");
        }
        cas.storeAttachment(hash, bytes);
        // storage_location 由当前 CAS 实现的 storageLocationTag() 决定（local / cos）。
        upsertMetadata(hash, bytes.length, userId, cas.storageLocationTag());
        return ApiResponse.ok(new AttachmentUploadResult(hash, bytes.length, "attachments/" + hash));
    }

    @GetMapping("/{hash}")
    @Operation(summary = "下载附件（按 hash）",
            description = "流式返回字节（磁盘 CAS 支持 Range/206），immutable 缓存；缺失 404、非法 hash 400")
    public ResponseEntity<Resource> download(@PathVariable String hash) {
        UserContext.requireUserId();
        if (hash == null || !HASH_RE.matcher(hash).matches()) {
            return ResponseEntity.badRequest().build();
        }
        if (!cas.existsAttachment(hash)) {
            return ResponseEntity.notFound().build();
        }
        // 能力式资源描述：磁盘 CAS 给 filePath（启用 Range），COS 给 stream（MVP 图片不启用 Range）。
        AttachmentResource resource = cas.attachmentResource(hash).orElse(null);
        if (resource == null) {
            return ResponseEntity.notFound().build();
        }
        touchLastUsed(hash);
        ResponseEntity.BodyBuilder builder = ResponseEntity.ok()
                .contentLength(resource.size())
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable");
        // 磁盘路径优先（启用 Spring Range/206）；否则用 COS 流。
        Resource body;
        if (resource.filePath().isPresent()) {
            body = new FileSystemResource(resource.filePath().get());
        } else if (resource.streamSupplier() != null) {
            body = new InputStreamResource(resource.streamSupplier().get());
        } else {
            return ResponseEntity.notFound().build();
        }
        return builder.body(body);
    }

    // ============================ 元数据 ============================

    /**
     * 上传 upsert：存在则 ref_count++，不存在则新建（owner = 当前用户）。
     * storageLocation 由 CAS 实现决定，标记附件落盘位置（local/cos），供混合方案迁移追踪。
     */
    private void upsertMetadata(String hash, long size, Long ownerUserId, String storageLocation) {
        attachmentRepository.findById(hash).ifPresentOrElse(
                existing -> {
                    existing.setRefCount(existing.getRefCount() + 1);
                    existing.setLastUsedAt(Instant.now());
                    attachmentRepository.save(existing);
                },
                () -> {
                    Attachment created = new Attachment();
                    created.setSha256(hash);
                    created.setSizeBytes(size);
                    created.setOwnerUserId(ownerUserId);
                    created.setRefCount(1);
                    created.setStorageLocation(storageLocation);
                    Instant now = Instant.now();
                    created.setCreatedAt(now);
                    created.setLastUsedAt(now);
                    attachmentRepository.save(created);
                }
        );
    }

    /** 下载成功后更新最近使用时间（失败不阻断下载）。 */
    private void touchLastUsed(String hash) {
        try {
            attachmentRepository.touchLastUsedAt(hash, Instant.now());
        } catch (Exception e) {
            log.warn("附件 last_used_at 更新失败（不影响下载）：hash={}, err={}", hash, e.getMessage());
        }
    }
}
