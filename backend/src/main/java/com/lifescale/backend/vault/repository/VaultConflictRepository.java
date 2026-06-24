package com.lifescale.backend.vault.repository;

import com.lifescale.backend.vault.entity.VaultConflict;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * vault 冲突记录仓储。
 */
public interface VaultConflictRepository extends JpaRepository<VaultConflict, Long> {

    /** 列出某用户指定状态（通常 "open"）的冲突，按创建时间倒序。 */
    List<VaultConflict> findByUserIdAndStatusOrderByCreatedAtDesc(Long userId, String status);

    /** 按 id + 用户查（解决时校验归属）。 */
    Optional<VaultConflict> findByIdAndUserId(Long id, Long userId);
}
