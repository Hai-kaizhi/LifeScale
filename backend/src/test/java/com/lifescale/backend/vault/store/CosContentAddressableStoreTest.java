package com.lifescale.backend.vault.store;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.model.COSObject;
import com.qcloud.cos.model.COSObjectInputStream;
import com.qcloud.cos.model.GetObjectRequest;
import com.qcloud.cos.model.ObjectMetadata;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * COS CAS 单测（P0-10）：mock COSClient，验证附件 store/exists/resource 走 COS，
 * 正文方法委托磁盘 CAS，storageLocationTag 返回 cos。
 */
class CosContentAddressableStoreTest {

    @TempDir
    Path tempDir;

    private COSClient cosClient;
    private FileSystemContentAddressableStore fsCas;
    private CosContentAddressableStore cosCas;

    @BeforeEach
    void setUp() {
        cosClient = mock(COSClient.class);
        fsCas = new FileSystemContentAddressableStore(tempDir.toString());
        cosCas = new CosContentAddressableStore(cosClient, "bucket", "att", fsCas);
    }

    @Test
    @DisplayName("正文方法委托磁盘 CAS（storeText 真实落盘）")
    void textDelegatesToFsCas() {
        String hash = cosCas.storeText("hello markdown");
        assertThat(hash).isNotBlank();
        assertThat(fsCas.exists(hash)).isTrue();
        assertThat(cosCas.readText(hash)).isEqualTo("hello markdown");
    }

    @Test
    @DisplayName("storeAttachment：对象不存在则 PUT，已存在则跳过（CAS 去重）")
    void storeAttachmentPutsWhenAbsent() {
        byte[] bytes = "image-bytes".getBytes();
        String hash = "ab".repeat(32); // 64 位 hex，前缀 ab
        when(cosClient.doesObjectExist("bucket", "att/ab/" + hash)).thenReturn(false);

        cosCas.storeAttachment(hash, bytes);

        verify(cosClient).putObject(any());
    }

    @Test
    @DisplayName("storeAttachment：对象已存在则跳过 PUT")
    void storeAttachmentSkipsWhenExists() {
        String hash = "ab".repeat(32);
        when(cosClient.doesObjectExist("bucket", "att/ab/" + hash)).thenReturn(true);

        cosCas.storeAttachment(hash, "x".getBytes());

        verify(cosClient, never()).putObject(any());
    }

    @Test
    @DisplayName("readAttachment：从 COS 流读取字节")
    void readAttachmentFromCos() throws Exception {
        byte[] bytes = "cos-content".getBytes();
        String hash = "cd".repeat(32);
        COSObjectInputStream stream = mock(COSObjectInputStream.class);
        when(stream.readAllBytes()).thenReturn(bytes);
        COSObject obj = mock(COSObject.class);
        when(obj.getObjectContent()).thenReturn(stream);
        when(cosClient.getObject(any(GetObjectRequest.class))).thenReturn(obj);

        byte[] read = cosCas.readAttachment(hash);
        assertThat(read).isEqualTo(bytes);
    }

    @Test
    @DisplayName("attachmentResource：返回 stream + size（filePath 空，不启用 Range）")
    void attachmentResourceReturnsStream() {
        String hash = "ef".repeat(32);
        ObjectMetadata meta = mock(ObjectMetadata.class);
        when(meta.getContentLength()).thenReturn(123L);
        when(cosClient.getObjectMetadata(eq("bucket"), eq("att/ef/" + hash))).thenReturn(meta);

        java.util.Optional<AttachmentResource> res = cosCas.attachmentResource(hash);
        assertThat(res).isPresent();
        assertThat(res.get().size()).isEqualTo(123L);
        assertThat(res.get().filePath()).isEmpty();
        assertThat(res.get().streamSupplier()).isNotNull();
    }

    @Test
    @DisplayName("storageLocationTag 返回 cos")
    void storageLocationTagIsCos() {
        assertThat(cosCas.storageLocationTag()).isEqualTo("cos");
    }

    @Test
    @DisplayName("existsAttachment 走 COS HEAD")
    void existsAttachmentQueriesCos() {
        String hash = "ab".repeat(32);
        when(cosClient.doesObjectExist("bucket", "att/ab/" + hash)).thenReturn(true);
        assertThat(cosCas.existsAttachment(hash)).isTrue();
    }
}
