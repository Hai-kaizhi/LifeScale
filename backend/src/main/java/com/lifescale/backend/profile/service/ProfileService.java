package com.lifescale.backend.profile.service;

import com.lifescale.backend.common.security.UnauthorizedException;
import com.lifescale.backend.profile.dto.UpdateProfileRequest;
import com.lifescale.backend.profile.dto.UserProfileDTO;
import com.lifescale.backend.profile.entity.UserProfile;
import com.lifescale.backend.profile.repository.UserProfileRepository;
import com.lifescale.backend.user.entity.User;
import com.lifescale.backend.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 用户个人资料读写服务。资料不存在时按默认值懒生成。
 */
@Service
public class ProfileService {

    private final UserProfileRepository profileRepository;
    private final UserRepository userRepository;

    public ProfileService(UserProfileRepository profileRepository, UserRepository userRepository) {
        this.profileRepository = profileRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public UserProfileDTO getProfile(Long userId) {
        UserProfile profile = profileRepository.findByUserId(userId)
                .orElseGet(() -> UserProfile.withDefaults(userId, resolveUsername(userId)));
        return toDto(profile);
    }

    @Transactional
    public UserProfileDTO updateProfile(Long userId, UpdateProfileRequest request) {
        UserProfile profile = profileRepository.findByUserId(userId)
                .orElseGet(() -> {
                    UserProfile p = UserProfile.withDefaults(userId, resolveUsername(userId));
                    return profileRepository.save(p);
                });
        if (request.nickname() != null && !request.nickname().isBlank()) {
            profile.setNickname(request.nickname().trim());
        }
        if (request.avatarUrl() != null) {
            profile.setAvatarUrl(request.avatarUrl().trim().isEmpty() ? null : request.avatarUrl().trim());
        }
        if (request.greeting() != null && !request.greeting().isBlank()) {
            profile.setGreeting(request.greeting().trim());
        }
        if (request.motivationalQuote() != null && !request.motivationalQuote().isBlank()) {
            profile.setMotivationalQuote(request.motivationalQuote().trim());
        }
        profileRepository.save(profile);
        return toDto(profile);
    }

    /** 注册成功后初始化默认资料；供 AuthService 调用，避免懒生成的额外写。 */
    @Transactional
    public void initDefaultProfile(Long userId, String username) {
        if (profileRepository.findByUserId(userId).isPresent()) {
            return;
        }
        profileRepository.save(UserProfile.withDefaults(userId, username));
    }

    private String resolveUsername(Long userId) {
        return userRepository.findById(userId).map(User::getUsername).orElse("用户");
    }

    private UserProfileDTO toDto(UserProfile p) {
        return new UserProfileDTO(p.getNickname(), p.getAvatarUrl(), p.getGreeting(), p.getMotivationalQuote());
    }
}
