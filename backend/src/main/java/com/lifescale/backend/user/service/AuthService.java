package com.lifescale.backend.user.service;

import com.lifescale.backend.common.security.UnauthorizedException;
import com.lifescale.backend.profile.service.ProfileService;
import com.lifescale.backend.user.dto.AuthSession;
import com.lifescale.backend.user.dto.DeviceDTO;
import com.lifescale.backend.user.dto.DeviceRequest;
import com.lifescale.backend.user.entity.Device;
import com.lifescale.backend.user.entity.User;
import com.lifescale.backend.user.invitecode.service.InviteCodeService;
import com.lifescale.backend.user.repository.DeviceRepository;
import com.lifescale.backend.user.repository.UserRepository;
import com.lifescale.backend.user.util.PasswordPolicy;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * 账号、登录、设备注册服务。密码用 BCrypt 校验。
 */
@Service
public class AuthService {

    private static final String STATUS_ACTIVE = "active";

    private final UserRepository userRepository;
    private final DeviceRepository deviceRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final DeviceCacheService deviceCacheService;
    private final InviteCodeService inviteCodeService;
    private final ProfileService profileService;

    public AuthService(UserRepository userRepository, DeviceRepository deviceRepository,
                       PasswordEncoder passwordEncoder, JwtService jwtService,
                       DeviceCacheService deviceCacheService, InviteCodeService inviteCodeService,
                       ProfileService profileService) {
        this.userRepository = userRepository;
        this.deviceRepository = deviceRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.deviceCacheService = deviceCacheService;
        this.inviteCodeService = inviteCodeService;
        this.profileService = profileService;
    }

    @Transactional
    public AuthSession register(String username, String password, String email, String inviteCode) {
        if (username == null || username.isBlank()) {
            throw new IllegalArgumentException("用户名不能为空");
        }
        // P0-8：集中式密码强度校验（≥8 位 + 字母与数字）
        PasswordPolicy.validate(password);
        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("用户名已存在");
        }
        User user = new User();
        user.setUsername(username);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setStatus(STATUS_ACTIVE);
        userRepository.save(user);
        // P0-7：邀请码校验+原子核销。放在用户创建之后：
        // 1) @Transactional 保证核销失败（邀请码无效/已用/过期）时用户创建一并回滚，不留半成品；
        // 2) 用新用户 ID 回填 used_by_user_id。enabled=false 时直接放行（local 兼容）。
        inviteCodeService.requireAndConsume(inviteCode, user.getId());
        // 注册即初始化默认个人资料（昵称默认取用户名），避免首次进入设置中心时懒生成。
        profileService.initDefaultProfile(user.getId(), user.getUsername());
        return toSession(user, null);
    }

    @Transactional
    public AuthSession login(String username, String password) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("用户名或密码错误"));
        if (!passwordEncoder.matches(password == null ? "" : password, user.getPasswordHash())) {
            throw new UnauthorizedException("用户名或密码错误");
        }
        if (!STATUS_ACTIVE.equals(user.getStatus())) {
            throw new UnauthorizedException("账号已禁用");
        }
        return toSession(user, null);
    }

    @Transactional(readOnly = true)
    public User currentUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new UnauthorizedException("用户不存在"));
    }

    @Transactional
    public DeviceDTO upsertDevice(Long userId, DeviceRequest request) {
        Device device = deviceRepository.findByUserIdAndDeviceId(userId, request.deviceId())
                .orElseGet(() -> {
                    Device d = new Device();
                    d.setUserId(userId);
                    d.setDeviceId(request.deviceId());
                    return d;
                });
        if (request.name() != null) {
            device.setName(request.name());
        }
        if (request.platform() != null) {
            device.setPlatform(request.platform());
        }
        device.setLastSeenAt(Instant.now());
        deviceRepository.save(device);
        // 设备信息变更，失效该用户设备列表缓存（写穿透失效）。
        deviceCacheService.evict(userId);
        return toDto(device);
    }

    @Transactional
    public void touchLastSeen(Long userId, String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            return;
        }
        deviceRepository.findByUserIdAndDeviceId(userId, deviceId).ifPresent(d -> {
            d.setLastSeenAt(Instant.now());
            deviceRepository.save(d);
        });
    }

    @Transactional(readOnly = true)
    public List<DeviceDTO> listDevices(Long userId) {
        // 读多写少：走短期缓存，命中直接返回；未命中查库后回写。Redis 异常自动降级。
        return deviceCacheService.getOrLoad(userId, () -> deviceRepository.findByUserIdOrderByUpdatedAtDesc(userId).stream()
                .map(this::toDto)
                .toList());
    }

    private AuthSession toSession(User user, String deviceId) {
        JwtService.IssuedToken issued = jwtService.issue(user.getId(), user.getUsername(), deviceId);
        return new AuthSession(user.getId(), user.getUsername(), user.getEmail(),
                issued.token(), str(issued.expiresAt()));
    }

    private DeviceDTO toDto(Device d) {
        return new DeviceDTO(d.getId(), d.getDeviceId(), d.getName(), d.getPlatform(),
                str(d.getLastSyncedAt()), str(d.getLastSeenAt()));
    }

    private String str(Instant instant) {
        return instant == null ? null : instant.toString();
    }
}
