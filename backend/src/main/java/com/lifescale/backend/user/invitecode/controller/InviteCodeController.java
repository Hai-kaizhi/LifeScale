package com.lifescale.backend.user.invitecode.controller;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.user.invitecode.dto.InviteCodeView;
import com.lifescale.backend.user.invitecode.service.InviteCodeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 邀请码管理接口（P0-7）。任意已登录用户可签发/查看自己的邀请码。
 * 注册接口仍由 {@link com.lifescale.backend.user.controller.AuthController AuthController} 暴露，
 * 校验逻辑在 {@link InviteCodeService#requireAndConsume} 内完成。
 */
@RestController
@RequestMapping("/api/auth/invite-codes")
@Tag(name = "邀请码", description = "邀请码生成与查询（注册加固）")
public class InviteCodeController {

    private final InviteCodeService inviteCodeService;

    public InviteCodeController(InviteCodeService inviteCodeService) {
        this.inviteCodeService = inviteCodeService;
    }

    @PostMapping
    @Operation(summary = "签发一个新邀请码（任意已登录用户）")
    public ApiResponse<InviteCodeView> generate() {
        Long userId = UserContext.requireUserId();
        return ApiResponse.ok(inviteCodeService.generate(userId));
    }

    @GetMapping
    @Operation(summary = "查看自己签发的邀请码列表")
    public ApiResponse<List<InviteCodeView>> mine() {
        Long userId = UserContext.requireUserId();
        return ApiResponse.ok(inviteCodeService.listMine(userId));
    }
}
