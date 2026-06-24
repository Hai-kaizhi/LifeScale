package com.lifescale.backend.user.controller;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.user.dto.AuthSession;
import com.lifescale.backend.user.dto.DeviceDTO;
import com.lifescale.backend.user.dto.DeviceRequest;
import com.lifescale.backend.user.dto.LoginRequest;
import com.lifescale.backend.user.dto.RegisterRequest;
import com.lifescale.backend.user.entity.User;
import com.lifescale.backend.user.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 账号与鉴权接口：注册 / 登录 / 当前用户 / 设备注册。
 */
@RestController
@RequestMapping("/api/auth")
@Tag(name = "账号与鉴权", description = "注册、登录、当前用户、设备注册")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @Operation(summary = "注册账号并返回 JWT")
    public ApiResponse<AuthSession> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.ok(authService.register(request.username(), request.password(), request.email(),
                request.inviteCode()));
    }

    @PostMapping("/login")
    @Operation(summary = "登录获取 JWT")
    public ApiResponse<AuthSession> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.ok(authService.login(request.username(), request.password()));
    }

    @GetMapping("/me")
    @Operation(summary = "获取当前登录用户")
    public ApiResponse<CurrentUser> me() {
        User user = authService.currentUser(UserContext.requireUserId());
        return ApiResponse.ok(new CurrentUser(user.getId(), user.getUsername(), user.getEmail()));
    }

    @PostMapping("/devices")
    @Operation(summary = "注册或更新当前设备")
    public ApiResponse<DeviceDTO> upsertDevice(@Valid @RequestBody DeviceRequest request) {
        return ApiResponse.ok(authService.upsertDevice(UserContext.requireUserId(), request));
    }

    @GetMapping("/devices")
    @Operation(summary = "当前用户的设备列表")
    public ApiResponse<List<DeviceDTO>> devices() {
        return ApiResponse.ok(authService.listDevices(UserContext.requireUserId()));
    }

    /** 当前登录用户精简信息。 */
    public record CurrentUser(Long id, String username, String email) {
    }
}
