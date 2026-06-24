package com.lifescale.backend.vault.conflict;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.lifescale.backend.vault.dto.ConflictItem;
import com.lifescale.backend.vault.dto.ConflictResolveRequest;
import com.lifescale.backend.vault.dto.VaultFileData;
import com.lifescale.backend.vault.entity.VaultConflict;
import com.lifescale.backend.vault.entity.VaultFile;
import com.lifescale.backend.vault.repository.VaultConflictRepository;
import com.lifescale.backend.vault.repository.VaultFileRepository;
import com.lifescale.backend.vault.repository.VaultVersionRepository;
import com.lifescale.backend.vault.service.VaultService;
import com.lifescale.backend.vault.store.FileSystemContentAddressableStore;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

/**
 * 冲突查询/解决逻辑单测：真实 FileSystemCAS（临时目录）+ mock 三个 repository。
 * 聚焦 VaultService.listConflicts / resolveConflict 的核心分支。
 */
class VaultConflictApiTest {

    private static final Long USER_ID = 10001L;

    @TempDir
    Path tempDir;

    private VaultFileRepository fileRepo;
    private VaultVersionRepository versionRepo;
    private VaultConflictRepository conflictRepo;
    private FileSystemContentAddressableStore cas;
    private VaultService service;

    @BeforeEach
    void setUp() {
        cas = new FileSystemContentAddressableStore(tempDir.toString());
        fileRepo = mock(VaultFileRepository.class);
        versionRepo = mock(VaultVersionRepository.class);
        conflictRepo = mock(VaultConflictRepository.class);
        service = new VaultService(fileRepo, versionRepo, conflictRepo, cas);
    }

    @AfterEach
    void tearDown() {
        // UserContext 在本测试不涉及（listConflicts/resolveConflict 直接传 userId）。
    }

    @Test
    @DisplayName("listConflicts：返回 open 冲突且含 theirs 内容")
    void listConflictsReturnsOpenWithTheirsContent() {
        String theirsContent = "# 云端版本\n服务端内容";
        String theirsHash = cas.storeText(theirsContent);
        VaultConflict c = newConflict(7L, "Notes/x.md", "minehash", theirsHash, "Notes/x.conflict-1.md", "open");
        when(conflictRepo.findByUserIdAndStatusOrderByCreatedAtDesc(USER_ID, "open"))
                .thenReturn(List.of(c));

        List<ConflictItem> items = service.listConflicts(USER_ID);

        assertThat(items).hasSize(1);
        ConflictItem item = items.get(0);
        assertThat(item.vaultPath()).isEqualTo("Notes/x.md");
        assertThat(item.theirsHash()).isEqualTo(theirsHash);
        assertThat(item.theirsContent()).isEqualTo(theirsContent);
        assertThat(item.status()).isEqualTo("open");
    }

    @Test
    @DisplayName("resolveConflict keepMine：以本机内容覆盖正本 + 标 resolved + 回写 merged_hash")
    void resolveKeepMineOverwritesAndMarksResolved() {
        String theirsContent = "云端";
        String theirsHash = cas.storeText(theirsContent);
        VaultConflict c = newConflict(5L, "Notes/y.md", "minehash", theirsHash, "Notes/y.conflict.md", "open");
        when(conflictRepo.findByIdAndUserId(5L, USER_ID)).thenReturn(Optional.of(c));
        // 模拟正本存在（version=3）。
        VaultFile current = new VaultFile();
        current.setUserId(USER_ID);
        current.setVaultPath("Notes/y.md");
        current.setContentHash(theirsHash);
        current.setVersion(3);
        current.setStatus("active");
        when(fileRepo.findByUserIdAndVaultPath(USER_ID, "Notes/y.md")).thenReturn(Optional.of(current));

        VaultFileData data = service.resolveConflict(USER_ID, 5L,
                new ConflictResolveRequest("keepMine", "# 本机版本\n本地内容"));

        assertThat(data).isNotNull();
        assertThat(data.vaultPath()).isEqualTo("Notes/y.md");
        assertThat(data.content()).contains("本机版本");
        assertThat(data.version()).isEqualTo(4); // version + 1
        // merged_hash = 新内容 hash，status=resolved。
        assertThat(c.getMergedHash()).isEqualTo(data.contentHash());
        assertThat(c.getStatus()).isEqualTo("resolved");
        verify(conflictRepo).save(c);
    }

    @Test
    @DisplayName("resolveConflict keepTheirs：正本不动 + 标 resolved + merged_hash=theirs")
    void resolveKeepTheirsPreservesServerAndMarksResolved() {
        String theirsContent = "保留云端";
        String theirsHash = cas.storeText(theirsContent);
        VaultConflict c = newConflict(9L, "Notes/z.md", "minehash", theirsHash, "Notes/z.conflict.md", "open");
        when(conflictRepo.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(c));
        VaultFile current = new VaultFile();
        current.setUserId(USER_ID);
        current.setVaultPath("Notes/z.md");
        current.setContentHash(theirsHash);
        current.setVersion(2);
        current.setStatus("active");
        when(fileRepo.findByUserIdAndVaultPath(USER_ID, "Notes/z.md")).thenReturn(Optional.of(current));

        VaultFileData data = service.resolveConflict(USER_ID, 9L,
                new ConflictResolveRequest("keepTheirs", null));

        // keepTheirs 返回 getFile 结果（正本内容）。
        assertThat(data).isNotNull();
        assertThat(data.content()).isEqualTo(theirsContent);
        assertThat(c.getMergedHash()).isEqualTo(theirsHash);
        assertThat(c.getStatus()).isEqualTo("resolved");
    }

    @Test
    @DisplayName("resolveConflict：冲突不存在/非本人 → 返回 null，不标记")
    void resolveNonexistentReturnsNull() {
        when(conflictRepo.findByIdAndUserId(999L, USER_ID)).thenReturn(Optional.empty());

        VaultFileData data = service.resolveConflict(USER_ID, 999L,
                new ConflictResolveRequest("keepMine", "x"));

        assertThat(data).isNull();
        verify(conflictRepo, never()).save(any(VaultConflict.class));
    }

    // ============================ helpers ============================

    private VaultConflict newConflict(long id, String path, String mineHash,
                                      String theirsHash, String copyPath, String status) {
        VaultConflict c = new VaultConflict();
        c.setUserId(USER_ID);
        c.setVaultPath(path);
        c.setMineHash(mineHash);
        c.setTheirsHash(theirsHash);
        c.setConflictCopyPath(copyPath);
        c.setStatus(status);
        // id 是 @GeneratedValue IDENTITY，单测中不被填充；createdAt 由 @CreatedDate 自动填充，无 setter。
        return c;
    }
}
