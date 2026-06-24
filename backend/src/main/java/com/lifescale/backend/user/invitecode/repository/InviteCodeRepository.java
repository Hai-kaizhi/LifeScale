package com.lifescale.backend.user.invitecode.repository;

import com.lifescale.backend.user.invitecode.entity.InviteCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * 邀请码仓储。核销用条件 UPDATE 保证原子性（status='unused' 才能被该请求命中）。
 */
public interface InviteCodeRepository extends JpaRepository<InviteCode, Long> {

    Optional<InviteCode> findByCode(String code);

    List<InviteCode> findByCreatedByUserIdOrderByCreatedAtDesc(long createdByUserId);

    /**
     * 原子核销：仅当 code 存在、status=unused、未过期（或 expires_at 为空）时，
     * 置为 used 并回填使用者。返回受影响行数：1=成功，0=已被并发抢占/不存在/已过期。
     */
    @Modifying
    @Query("update InviteCode i set i.status = 'used', i.usedByUserId = :userId, i.usedAt = :now " +
            "where i.code = :code and i.status = 'unused' " +
            "and (i.expiresAt is null or i.expiresAt > :now)")
    int consumeIfAvailable(@Param("code") String code,
                           @Param("userId") long userId,
                           @Param("now") Instant now);
}
