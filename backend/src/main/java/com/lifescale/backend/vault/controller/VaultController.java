package com.lifescale.backend.vault.controller;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.vault.dto.ConflictItem;
import com.lifescale.backend.vault.dto.ConflictResolveRequest;
import com.lifescale.backend.vault.dto.VaultChangesData;
import com.lifescale.backend.vault.dto.VaultFileData;
import com.lifescale.backend.vault.dto.VaultPushPayload;
import com.lifescale.backend.vault.dto.VaultPushResult;
import com.lifescale.backend.vault.dto.VaultVersionSummary;
import com.lifescale.backend.vault.service.VaultService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Vault 同步接口（路径中心）：增量变更、文件读写推送、删除（墓碑）、版本历史。
 * 全部需登录（JWT），按当前用户隔离。
 */
@RestController
@RequestMapping("/api/vault")
@Tag(name = "Vault 多端同步", description = "Obsidian 风格 vault 文件同步：增量拉取、乐观锁推送、三方合并、冲突副本")
public class VaultController {

    private final VaultService vaultService;

    public VaultController(VaultService vaultService) {
        this.vaultService = vaultService;
    }

    @GetMapping("/changes")
    @Operation(summary = "增量变更摘要", description = "按 updated_at 游标拉取变更摘要（含删除墓碑），不含正文")
    public ApiResponse<VaultChangesData> changes(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) Integer limit) {
        return ApiResponse.ok(vaultService.changes(UserContext.requireUserId(), since, limit));
    }

    @GetMapping("/files")
    @Operation(summary = "拉取单个文件正文", description = "按 vaultPath 拉取正文 + hash + version")
    public ApiResponse<VaultFileData> file(@RequestParam String path) {
        VaultFileData data = vaultService.getFile(UserContext.requireUserId(), path);
        if (data == null) {
            return ApiResponse.fail(404, "文件不存在或已删除");
        }
        return ApiResponse.ok(data);
    }

    @PutMapping("/files")
    @Operation(summary = "推送文件（乐观锁 + 三方合并）",
            description = "outcome: created/ok/merged/conflict；conflict 时 data=null 且 conflict 带详情")
    public ApiResponse<VaultPushResult> push(@Valid @RequestBody VaultPushPayload payload) {
        return ApiResponse.ok(vaultService.push(UserContext.requireUserId(), payload));
    }

    @DeleteMapping("/files")
    @Operation(summary = "删除文件（墓碑）", description = "软删，下发 status=deleted 变更事件到其他设备")
    public ApiResponse<Void> delete(@RequestParam String path, @RequestParam(required = false) String deviceId) {
        boolean ok = vaultService.delete(UserContext.requireUserId(), path, deviceId);
        return ok ? ApiResponse.ok() : ApiResponse.fail(404, "文件不存在");
    }

    @GetMapping("/files/versions")
    @Operation(summary = "版本历史摘要", description = "按版本号倒序返回最近 N 个版本")
    public ApiResponse<List<VaultVersionSummary>> versions(
            @RequestParam String path,
            @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.ok(vaultService.versions(UserContext.requireUserId(), path, limit));
    }

    // ---- 冲突查询 / 解决（阶段九）----

    @GetMapping("/conflicts")
    @Operation(summary = "列出未解决冲突", description = "返回当前用户所有 open 冲突，含 theirs 内容预览，供移动端冲突中心页展示")
    public ApiResponse<List<ConflictItem>> conflicts() {
        return ApiResponse.ok(vaultService.listConflicts(UserContext.requireUserId()));
    }

    @PostMapping("/conflicts/{id}/resolve")
    @Operation(summary = "解决冲突", description = "strategy: keepMine(以 content 覆盖正本)/keepTheirs(保留正本)；标记 resolved 并回写 merged_hash")
    public ApiResponse<VaultFileData> resolveConflict(
            @PathVariable Long id,
            @Valid @RequestBody ConflictResolveRequest req) {
        VaultFileData data = vaultService.resolveConflict(UserContext.requireUserId(), id, req);
        if (data == null) {
            return ApiResponse.fail(404, "冲突不存在或无权处理");
        }
        return ApiResponse.ok(data);
    }

    @PostMapping("/heartbeat")
    @Operation(summary = "设备心跳（预留）", description = "记录设备活跃，便于异常提示")
    public ApiResponse<Void> heartbeat() {
        // 设备 lastSeen 触摸由 /api/auth/devices 承担；此处保留端点便于客户端固定上报。
        return ApiResponse.ok();
    }
}
