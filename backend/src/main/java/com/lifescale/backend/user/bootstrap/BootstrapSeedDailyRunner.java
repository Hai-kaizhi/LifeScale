package com.lifescale.backend.user.bootstrap;

import com.lifescale.backend.user.entity.User;
import com.lifescale.backend.user.repository.UserRepository;
import com.lifescale.backend.vault.entity.VaultFile;
import com.lifescale.backend.vault.entity.VaultVersion;
import com.lifescale.backend.vault.repository.VaultFileRepository;
import com.lifescale.backend.vault.repository.VaultVersionRepository;
import com.lifescale.backend.vault.store.ContentAddressableStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * 首启兜底：为引导默认用户写入「今天」的沉淀 Daily 快照（docs/09 §12.1 干净文法，零注释），
 * 作为已沉淀的历史示例 .md 进入 Notes/Daily/，确保客户端登录后笔记侧有示例内容。
 * <p>
 * P6 收尾：从旧的带行尾注释 Daily/ 文法迁移为干净 Notes/Daily/ 沉淀文法
 * （docs/09 §5.3 当天数据在 SQL，.md 是沉淀产物）。幂等：同路径已有 active 记录则跳过。
 * 复用 CAS + ls_vault_file + ls_vault_version。
 */
@Component
@Order(30)
public class BootstrapSeedDailyRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(BootstrapSeedDailyRunner.class);
    private static final String STATUS_ACTIVE = "active";
    private static final String VAULT_DEVICE_ID = "server-bootstrap";

    private final UserRepository userRepository;
    private final VaultFileRepository vaultFileRepository;
    private final VaultVersionRepository vaultVersionRepository;
    private final ContentAddressableStore cas;
    private final String bootstrapUsername;

    public BootstrapSeedDailyRunner(UserRepository userRepository,
                                    VaultFileRepository vaultFileRepository,
                                    VaultVersionRepository vaultVersionRepository,
                                    ContentAddressableStore cas,
                                    @Value("${lifescale.auth.bootstrap.username:lifescale}") String bootstrapUsername) {
        this.userRepository = userRepository;
        this.vaultFileRepository = vaultFileRepository;
        this.vaultVersionRepository = vaultVersionRepository;
        this.cas = cas;
        this.bootstrapUsername = bootstrapUsername;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        User user = userRepository.findByUsername(bootstrapUsername).orElse(null);
        if (user == null) {
            return;
        }
        String today = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE);
        String vaultPath = "Notes/Daily/" + today + ".md";
        if (vaultFileRepository.findByUserIdAndVaultPath(user.getId(), vaultPath)
                .filter(f -> STATUS_ACTIVE.equals(f.getStatus()))
                .isPresent()) {
            return;
        }
        String content = buildTodayDaily(today);
        String hash = cas.storeText(content);
        long size = content.getBytes(StandardCharsets.UTF_8).length;

        VaultFile file = new VaultFile();
        file.setUserId(user.getId());
        file.setVaultPath(vaultPath);
        file.setContentHash(hash);
        file.setSizeBytes(size);
        file.setVersion(1);
        file.setStatus(STATUS_ACTIVE);
        file.setLastModifiedDeviceId(VAULT_DEVICE_ID);
        vaultFileRepository.save(file);

        VaultVersion version = new VaultVersion();
        version.setUserId(user.getId());
        version.setVaultPath(vaultPath);
        version.setVersion(1);
        version.setContentHash(hash);
        version.setSizeBytes(size);
        version.setDeviceId(VAULT_DEVICE_ID);
        vaultVersionRepository.save(version);

        log.info("引导写入默认用户 {} 的今日 Daily：{}", bootstrapUsername, vaultPath);
    }

    /**
     * 构造今日 Daily Markdown（docs/09 §12.1 沉淀纯净文法，零 `<!-- -->` 注释）。
     * 与桌面 serializeCleanDailyDoc / 移动 DailyDocSerializer.serializeClean 1:1 对齐。
     */
    private String buildTodayDaily(String date) {
        return "# " + date + "\n"
                + "\n"
                + "## 今日重点\n"
                + "- 把今天最重要的两件事做完\n"
                + "\n"
                + "## 今日日程\n"
                + "- [ ] 09:00-10:00 同步联调（工作）\n"
                + "- [ ] 14:00-15:00 整理复盘四问（生活）\n"
                + "### 时间记录\n"
                + "- 16:30-17:00 阅读时间记录（工作）\n"
                + "\n"
                + "## 快速记录\n"
                + "- 09:30 移动端首次同步完成\n"
                + "\n"
                + "## 今日复盘\n"
                + "### 今天完成了什么？\n"
                + "暂无。\n"
                + "### 哪里可以做得更好？\n"
                + "暂无。\n";
    }
}
