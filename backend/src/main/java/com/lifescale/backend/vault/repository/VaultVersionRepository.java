package com.lifescale.backend.vault.repository;

import com.lifescale.backend.vault.entity.VaultVersion;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * vault 版本历史仓储。
 */
public interface VaultVersionRepository extends JpaRepository<VaultVersion, Long> {

    /** 校验某 hash 是否确为该路径的历史版本（三方合并 base 反查 + 防注入）。 */
    boolean existsByUserIdAndVaultPathAndContentHash(Long userId, String vaultPath, String contentHash);

    Page<VaultVersion> findByUserIdAndVaultPathOrderByVersionDesc(Long userId, String vaultPath, Pageable pageable);
}
