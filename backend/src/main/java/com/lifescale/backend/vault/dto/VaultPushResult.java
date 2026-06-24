package com.lifescale.backend.vault.dto;

/**
 * 推送结果。outcome 取值：
 * <ul>
 *   <li>created —— 新建（服务端原本无此路径）</li>
 *   <li>ok —— 无冲突快进更新</li>
 *   <li>merged —— 三方自动合并成功</li>
 *   <li>conflict —— 无法自动合并，已生成冲突副本；data=null，conflict 带详情</li>
 * </ul>
 * 用 outcome 判别，不依赖 HTTP 状态码。
 */
public record VaultPushResult(
        String outcome,
        VaultFileData data,
        ConflictView conflict) {
}
