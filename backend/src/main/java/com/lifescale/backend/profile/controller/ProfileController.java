package com.lifescale.backend.profile.controller;

import com.lifescale.backend.common.model.ApiResponse;
import com.lifescale.backend.common.security.UserContext;
import com.lifescale.backend.profile.dto.UpdateProfileRequest;
import com.lifescale.backend.profile.dto.UserProfileDTO;
import com.lifescale.backend.profile.service.ProfileService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 用户个人资料接口（需登录）。
 */
@RestController
@RequestMapping("/api/user/profile")
@Tag(name = "个人资料", description = "昵称、头像、问候语、每日提示")
public class ProfileController {

    private final ProfileService profileService;

    public ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @GetMapping
    @Operation(summary = "获取当前用户个人资料")
    public ApiResponse<UserProfileDTO> getProfile() {
        return ApiResponse.ok(profileService.getProfile(UserContext.requireUserId()));
    }

    @PutMapping
    @Operation(summary = "更新当前用户个人资料（部分更新）")
    public ApiResponse<UserProfileDTO> updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return ApiResponse.ok(profileService.updateProfile(UserContext.requireUserId(), request));
    }
}
