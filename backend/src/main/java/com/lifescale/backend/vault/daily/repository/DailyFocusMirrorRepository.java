package com.lifescale.backend.vault.daily.repository;

import com.lifescale.backend.vault.daily.entity.DailyFocusMirror;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

/**
 * 今日重点镜像仓储（以 date 为业务身份；LWW 同步 + 增量游标）。
 */
public interface DailyFocusMirrorRepository extends JpaRepository<DailyFocusMirror, Long> {

    Optional<DailyFocusMirror> findByUserIdAndDate(Long userId, LocalDate date);

    Page<DailyFocusMirror> findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(Long userId, Instant since, Pageable pageable);
}
