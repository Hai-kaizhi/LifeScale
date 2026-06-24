package com.lifescale.backend.vault.daily.controller;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityChangesData;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityPushPayload;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntitySyncResult;
import com.lifescale.backend.vault.daily.service.DailyEntitySyncService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Daily 当天实体同步接口（docs/09 §9.3）：当天未沉淀实体跨设备 LWW 同步。
 * 全部需登录（JWT），按当前用户隔离。沉淀后转走 /api/vault 文件同步。
 */
@RestController
@RequestMapping("/api/vault/daily-entities")
@Tag(name = "Daily 实体同步", description = "当天未沉淀实体跨设备 last-write-wins 同步（沉淀后转 vault 文件同步）")
public class DailyEntitySyncController {

    private final DailyEntitySyncService syncService;

    public DailyEntitySyncController(DailyEntitySyncService syncService) {
        this.syncService = syncService;
    }

    @PutMapping
    @Operation(summary = "推送当天实体（LWW）",
            description = "批量推送 4 类当天未沉淀实体，服务端按 updatedAt 取最新（LWW）；墓碑传播")
    public ApiResponse<DailyEntitySyncResult> push(@Valid @RequestBody DailyEntityPushPayload payload) {
        return ApiResponse.ok(syncService.pushEntities(UserContext.requireUserId(), payload));
    }

    @GetMapping("/changes")
    @Operation(summary = "增量变更（游标）", description = "按 updated_at 游标拉取 4 类实体增量变更（含删除墓碑）")
    public ApiResponse<DailyEntityChangesData> changes(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) Integer limit) {
        return ApiResponse.ok(syncService.getChanges(UserContext.requireUserId(), since, limit));
    }
}
