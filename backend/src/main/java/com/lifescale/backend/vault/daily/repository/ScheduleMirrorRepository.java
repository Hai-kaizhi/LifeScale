package com.lifescale.backend.vault.daily.repository;

import com.lifescale.backend.vault.daily.entity.ScheduleMirror;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

/**
 * 日程镜像仓储（LWW 同步 + 增量游标）。
 */
public interface ScheduleMirrorRepository extends JpaRepository<ScheduleMirror, Long> {

    Optional<ScheduleMirror> findByUserIdAndEntityId(Long userId, String entityId);

    /** 增量变更游标：按 updated_at 升序、严格晚于 since（墓碑也会被带出）。 */
    Page<ScheduleMirror> findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(Long userId, Instant since, Pageable pageable);
}
