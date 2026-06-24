package com.lifescale.backend.vault.attachment.repository;

import com.lifescale.backend.vault.attachment.entity.Attachment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;

/**
 * 附件元数据仓储（主键为 SHA-256）。
 */
public interface AttachmentRepository extends JpaRepository<Attachment, String> {

    /** 下载成功后更新 last_used_at（touch）。失败不阻断下载，故用 @Modifying 静默执行。 */
    @Modifying
    @Query("update Attachment a set a.lastUsedAt = :now where a.sha256 = :hash")
    int touchLastUsedAt(@Param("hash") String hash, @Param("now") Instant now);
}
