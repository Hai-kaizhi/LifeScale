package com.lifescale.backend.user.invitecode.service;

import com.lifescale.backend.user.invitecode.dto.InviteCodeView;
import com.lifescale.backend.user.invitecode.entity.InviteCode;
import com.lifescale.backend.user.invitecode.repository.InviteCodeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * 邀请码服务（P0-7）：
 * - generate：任意已登录用户签发一个 URL 安全随机邀请码，TTL 由配置控制。
 * - consume：原子核销（条件 UPDATE，并发安全），返回是否成功。
 * - requireConsumable：注册前置校验，邀请码缺失/无效时抛 IllegalArgumentException（→ 400）。
 * - listMine：生成者查看自己签发的邀请码。
 */
@Service
public class InviteCodeService {

    private static final Logger log = LoggerFactory.getLogger(InviteCodeService.class);

    /** URL 安全字母表（无易混淆字符 0/O/1/I/l）。 */
    private static final char[] ALPHABET =
            "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789".toCharArray();
    private static final int CODE_LENGTH = 24;
    private static final String STATUS_UNUSED = "unused";
    private static final String STATUS_USED = "used";

    private final InviteCodeRepository inviteCodeRepository;
    private final SecureRandom random = new SecureRandom();
    private final long ttlDays;
    private final boolean enabled;

    public InviteCodeService(InviteCodeRepository inviteCodeRepository,
                             @Value("${lifescale.auth.invite-code.enabled:false}") boolean enabled,
                             @Value("${lifescale.auth.invite-code.ttl-days:7}") long ttlDays) {
        this.inviteCodeRepository = inviteCodeRepository;
        this.enabled = enabled;
        this.ttlDays = ttlDays;
    }

    /** 是否启用邀请码注册（local 默认 false，prod 强制 true）。 */
    public boolean isEnabled() {
        return enabled;
    }

    /** 签发一个新邀请码（调用方为任意已登录用户）。 */
    @Transactional
    public InviteCodeView generate(long createdByUserId) {
        InviteCode entity = new InviteCode();
        entity.setCode(newCode());
        entity.setCreatedByUserId(createdByUserId);
        entity.setStatus(STATUS_UNUSED);
        if (ttlDays > 0) {
            entity.setExpiresAt(Instant.now().plus(Duration.ofDays(ttlDays)));
        }
        inviteCodeRepository.save(entity);
        log.info("邀请码签发：createdBy={}, ttlDays={}", createdByUserId, ttlDays);
        return toView(entity);
    }

    /**
     * 注册流程：校验并原子核销邀请码。enabled=false 直接放行（local 兼容）。
     *
     * @param code         客户端提交的邀请码（enabled 时必填）
     * @param newUserId    新建用户的 ID，用于回填 used_by
     * @throws IllegalArgumentException 邀请码缺失/无效/已用/已过期（→ 400）
     */
    @Transactional
    public void requireAndConsume(String code, long newUserId) {
        if (!enabled) {
            return; // 未启用：不校验，保持旧行为
        }
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("邀请码不能为空");
        }
        int affected = inviteCodeRepository.consumeIfAvailable(code, newUserId, Instant.now());
        if (affected == 0) {
            // 失败原因细分：不存在 / 已用 / 撤销 / 过期
            InviteCode existing = inviteCodeRepository.findByCode(code).orElse(null);
            if (existing == null) {
                throw new IllegalArgumentException("邀请码无效");
            }
            throw new IllegalArgumentException("邀请码不可用（已使用或已过期）");
        }
        log.info("邀请码核销：code-prefix={}..., usedBy={}", code.substring(0, Math.min(4, code.length())), newUserId);
    }

    /** 生成者查看自己签发的邀请码列表。 */
    @Transactional(readOnly = true)
    public List<InviteCodeView> listMine(long createdByUserId) {
        return inviteCodeRepository.findByCreatedByUserIdOrderByCreatedAtDesc(createdByUserId)
                .stream().map(this::toView).toList();
    }

    // ============================ 辅助 ============================

    private String newCode() {
        char[] buf = new char[CODE_LENGTH];
        for (int i = 0; i < CODE_LENGTH; i++) {
            buf[i] = ALPHABET[random.nextInt(ALPHABET.length)];
        }
        return new String(buf);
    }

    private InviteCodeView toView(InviteCode i) {
        return new InviteCodeView(
                i.getCode(),
                i.getStatus(),
                i.getExpiresAt() == null ? null : i.getExpiresAt().toString(),
                i.getUsedByUserId(),
                i.getCreatedAt() == null ? null : i.getCreatedAt().toString());
    }
}
