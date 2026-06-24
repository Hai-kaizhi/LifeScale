package com.lifescale.backend.user.bootstrap;

import com.lifescale.backend.user.entity.User;
import com.lifescale.backend.user.repository.UserRepository;
import com.lifescale.backend.user.util.PasswordPolicy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Arrays;

/**
 * 首启兜底：当配置的引导用户名不存在时自动创建，避免单用户 MVP 在引入鉴权后被锁。
 * 用户名/密码由 lifescale.auth.bootstrap.* 配置，生产务必改强密码。
 * <p>
 * P0-6 生产加固：prod profile 下若 bootstrap 密码不满足 {@link PasswordPolicy}（如仍是默认弱值 lifescale），
 * 启动直接 fail-fast，逼运维通过 LIFESCALE_BOOTSTRAP_PASSWORD 注入强密码。该用户用于首次登录生成邀请码，
 * 因此保留创建能力（不禁用），只强制强密码。
 */
@Component
@Order(20)
public class BootstrapDefaultUserRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(BootstrapDefaultUserRunner.class);
    private static final String STATUS_ACTIVE = "active";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;
    private final String username;
    private final String password;

    public BootstrapDefaultUserRunner(UserRepository userRepository,
                                      PasswordEncoder passwordEncoder,
                                      Environment environment,
                                      @Value("${lifescale.auth.bootstrap.username:lifescale}") String username,
                                      @Value("${lifescale.auth.bootstrap.password:lifescale}") String password) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.environment = environment;
        this.username = username;
        this.password = password;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (userRepository.existsByUsername(username)) {
            return;
        }
        // prod 下强制 bootstrap 密码满足强度（复用注册策略），避免用默认 lifescale 上生产。
        boolean isProd = environment != null
                && Arrays.asList(environment.getActiveProfiles()).contains("prod");
        if (isProd) {
            try {
                PasswordPolicy.validate(password);
            } catch (IllegalArgumentException e) {
                throw new IllegalStateException(
                        "生产环境引导用户密码不合规：" + e.getMessage()
                                + "。请通过 LIFESCALE_BOOTSTRAP_PASSWORD 注入强密码（≥8 位 + 字母与数字）。", e);
            }
        }
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setStatus(STATUS_ACTIVE);
        userRepository.save(user);
        log.info("引导创建默认用户：{}（生产环境请改用强密码并尽快更换）", username);
    }
}
