package com.lifescale.backend.vault.daily.repository;

import com.lifescale.backend.vault.daily.entity.QuickNoteMirror;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

/**
 * 快速记录镜像仓储（LWW 同步 + 增量游标）。
 */
public interface QuickNoteMirrorRepository extends JpaRepository<QuickNoteMirror, Long> {

    Optional<QuickNoteMirror> findByUserIdAndEntityId(Long userId, String entityId);

    Page<QuickNoteMirror> findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(Long userId, Instant since, Pageable pageable);
}
