package com.lifescale.backend.vault.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 解决冲突请求（POST /api/vault/conflicts/{id}/resolve）。
 * <ul>
 *   <li>{@code keepMine} —— 以客户端 {@code content} 强制覆盖服务端正本（写新版本）。</li>
 *   <li>{@code keepTheirs} —— 放弃本机内容，保留服务端正本不动。</li>
 * </ul>
 * 两种策略都把冲突标记为 resolved 并回写 merged_hash。
 */
public record ConflictResolveRequest(
        @NotBlank String strategy,
        String content) {
}
