package com.lifescale.backend.vault.repository;

import com.lifescale.backend.vault.entity.VaultFile;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

/**
 * vault 文件索引仓储。
 */
public interface VaultFileRepository extends JpaRepository<VaultFile, Long> {

    Optional<VaultFile> findByUserIdAndVaultPath(Long userId, String vaultPath);

    /** 增量变更游标：按 updated_at 升序、严格晚于 since（墓碑也会被带出）。 */
    Page<VaultFile> findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(Long userId, Instant since, Pageable pageable);
}
