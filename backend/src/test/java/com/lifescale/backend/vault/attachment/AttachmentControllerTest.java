package com.lifescale.backend.vault.attachment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.vault.attachment.entity.Attachment;
import com.lifescale.backend.vault.attachment.repository.AttachmentRepository;
import com.lifescale.backend.vault.store.FileSystemContentAddressableStore;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;

import java.nio.file.Path;
import java.util.Optional;

/**
 * 附件控制器单测：用真实 {@link FileSystemContentAddressableStore}（临时 CAS 目录）+ mock
 * {@link AttachmentRepository}，覆盖下载流式/Range、非法 hash、缺失、上传去重与元数据 upsert。
 * <p>
 * {@link UserContext} 由 ThreadLocal 提供，测试前显式 setUserId，结束后 clear。
 */
class AttachmentControllerTest {

    @TempDir
    Path tempDir;

    private FileSystemContentAddressableStore cas;
    private AttachmentRepository repository;
    private AttachmentController controller;

    private static final Long USER_ID = 10001L;

    @BeforeEach
    void setUp() {
        cas = new FileSystemContentAddressableStore(tempDir.toString());
        repository = mock(AttachmentRepository.class);
        controller = new AttachmentController(cas, repository);
        UserContext.setUserId(USER_ID);
    }

    @AfterEach
    void tearDown() {
        UserContext.clear();
    }

    @Test
    @DisplayName("下载已存在附件：200 + 流式 Resource + Accept-Ranges/immutable 头")
    void downloadExistingReturnsStreamWithRangeHeaders() throws Exception {
        byte[] content = "fake-image-bytes".getBytes();
        String hash = hashOf(content);
        cas.storeAttachment(hash, content);

        ResponseEntity<Resource> res = controller.download(hash);

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(res.getHeaders().getFirst(HttpHeaders.ACCEPT_RANGES)).isEqualTo("bytes");
        assertThat(res.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL))
                .contains("immutable");
        assertThat(res.getHeaders().getContentLength()).isEqualTo(content.length);
        assertThat(res.getBody()).isNotNull();
        // 元数据 last_used_at 被 touch。
        verify(repository).touchLastUsedAt(eq(hash), any());
    }

    @Test
    @DisplayName("下载非法 hash（非 64 位 hex）：400")
    void downloadInvalidHashReturns400() {
        ResponseEntity<Resource> res = controller.download("not-a-hash");
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    @DisplayName("下载缺失附件：404")
    void downloadMissingReturns404() {
        String hash = "a".repeat(64);
        ResponseEntity<Resource> res = controller.download(hash);
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("上传：CAS 去重 + 新建元数据（owner=当前用户，ref_count=1，storage_location=local）")
    void uploadStoresCasAndCreatesMetadata() throws Exception {
        byte[] content = "hello-image".getBytes();
        String hash = hashOf(content);
        when(repository.findById(hash)).thenReturn(Optional.empty());

        MockMultipartFile file = new MockMultipartFile(
                "file", "a.png", "image/png", content);

        ApiResponse<AttachmentUploadResult> res = controller.upload(file);

        assertThat(res.success()).isTrue();
        AttachmentUploadResult data = res.data();
        assertThat(data.hash()).isEqualTo(hash);
        assertThat(data.size()).isEqualTo(content.length);
        assertThat(data.path()).isEqualTo("attachments/" + hash);
        // CAS 真实落盘。
        assertThat(cas.existsAttachment(hash)).isTrue();
        // 新建元数据：save 入参字段正确（含 storage_location 由磁盘 CAS 标记）。
        ArgumentCaptor<Attachment> captor = ArgumentCaptor.forClass(Attachment.class);
        verify(repository).save(captor.capture());
        Attachment saved = captor.getValue();
        assertThat(saved.getSha256()).isEqualTo(hash);
        assertThat(saved.getOwnerUserId()).isEqualTo(USER_ID);
        assertThat(saved.getRefCount()).isEqualTo(1);
        assertThat(saved.getStorageLocation()).isEqualTo("local");
    }

    @Test
    @DisplayName("上传重复附件：CAS 跳过 + 元数据 ref_count++")
    void uploadDeduplicatesAndIncrementsRefCount() throws Exception {
        byte[] content = "dup-image".getBytes();
        String hash = hashOf(content);
        Attachment existing = new Attachment();
        existing.setSha256(hash);
        existing.setOwnerUserId(USER_ID);
        existing.setRefCount(3);
        when(repository.findById(hash)).thenReturn(Optional.of(existing));

        MockMultipartFile file = new MockMultipartFile(
                "file", "dup.png", "image/png", content);

        ApiResponse<AttachmentUploadResult> res = controller.upload(file);

        assertThat(res.success()).isTrue();
        // 已存在 → ref_count 自增到 4。
        assertThat(existing.getRefCount()).isEqualTo(4);
        verify(repository, atLeastOnce()).save(existing);
    }

    // ============================ 辅助 ============================

    /** 与后端 ContentHasher 对齐的 SHA-256（小写 hex）。 */
    private static String hashOf(byte[] bytes) throws Exception {
        java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
        byte[] digest = md.digest(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : digest) {
            sb.append(Character.forDigit((b >> 4) & 0xF, 16));
            sb.append(Character.forDigit(b & 0xF, 16));
        }
        return sb.toString();
    }
}
