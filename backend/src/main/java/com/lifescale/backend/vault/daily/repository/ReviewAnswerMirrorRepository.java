package com.lifescale.backend.vault.daily.repository;

import com.lifescale.backend.vault.daily.entity.ReviewAnswerMirror;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

/**
 * 复盘答案镜像仓储（LWW 同步 + 增量游标）。
 */
public interface ReviewAnswerMirrorRepository extends JpaRepository<ReviewAnswerMirror, Long> {

    Optional<ReviewAnswerMirror> findByUserIdAndEntityId(Long userId, String entityId);

    Page<ReviewAnswerMirror> findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(Long userId, Instant since, Pageable pageable);
}
