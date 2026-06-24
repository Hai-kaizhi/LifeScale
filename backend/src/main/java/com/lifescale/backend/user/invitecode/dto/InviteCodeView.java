package com.lifescale.backend.user.invitecode.dto;

/**
 * 邀请码视图（生成者查看自己签发的邀请码列表）。
 *
 * @param code           邀请码 token
 * @param status         unused / used / revoked
 * @param expiresAt      过期时间（ISO instant，可空）
 * @param usedByUserId   使用者 ID（未使用为 null）
 * @param createdAt      创建时间
 */
public record InviteCodeView(String code, String status, String expiresAt, Long usedByUserId, String createdAt) {
}
