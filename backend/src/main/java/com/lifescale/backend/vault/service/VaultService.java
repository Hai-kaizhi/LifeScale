package com.lifescale.backend.vault.service;

import com.lifescale.backend.common.util.ContentHasher;
import com.lifescale.backend.vault.dto.ConflictItem;
import com.lifescale.backend.vault.dto.ConflictResolveRequest;
import com.lifescale.backend.vault.dto.ConflictView;
import com.lifescale.backend.vault.dto.VaultChangeSummary;
import com.lifescale.backend.vault.dto.VaultChangesData;
import com.lifescale.backend.vault.dto.VaultFileData;
import com.lifescale.backend.vault.dto.VaultPushPayload;
import com.lifescale.backend.vault.dto.VaultPushResult;
import com.lifescale.backend.vault.dto.VaultVersionSummary;
import com.lifescale.backend.vault.entity.VaultConflict;
import com.lifescale.backend.vault.entity.VaultFile;
import com.lifescale.backend.vault.entity.VaultVersion;
import com.lifescale.backend.vault.repository.VaultConflictRepository;
import com.lifescale.backend.vault.repository.VaultFileRepository;
import com.lifescale.backend.vault.repository.VaultVersionRepository;
import com.lifescale.backend.vault.store.ContentAddressableStore;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Optional;

/**
 * Vault 同步核心：推送（乐观锁 + 三方合并 + 冲突副本）、拉取（增量变更游标）、删除（墓碑）、版本历史。
 * <p>
 * 同步单位 = vault 相对路径 + 内容 hash；.md 文件保持纯净，元数据落库 + CAS。
 */
@Service
public class VaultService {

    private static final String STATUS_ACTIVE = "active";
    private static final String STATUS_DELETED = "deleted";

    private final VaultFileRepository fileRepo;
    private final VaultVersionRepository versionRepo;
    private final VaultConflictRepository conflictRepo;
    private final ContentAddressableStore cas;

    public VaultService(VaultFileRepository fileRepo, VaultVersionRepository versionRepo,
                        VaultConflictRepository conflictRepo, ContentAddressableStore cas) {
        this.fileRepo = fileRepo;
        this.versionRepo = versionRepo;
        this.conflictRepo = conflictRepo;
        this.cas = cas;
    }

    // ============================ 推送（乐观锁 + 三方合并） ============================

    @Transactional
    public VaultPushResult push(Long userId, VaultPushPayload payload) {
        String path = normalize(payload.vaultPath());
        String content = payload.content() == null ? "" : payload.content();
        VaultFile current = fileRepo.findByUserIdAndVaultPath(userId, path).orElse(null);
        boolean currentActive = current != null && STATUS_ACTIVE.equals(current.getStatus());

        // 服务端无活跃版本 → 新建
        if (!currentActive) {
            return create(userId, path, content, payload.deviceId());
        }

        // 客户端未提供 base，但服务端已有内容 → 视为冲突（服务端更新）
        if (payload.ifMatchHash() == null || payload.ifMatchHash().isBlank()) {
            return conflict(userId, path, content, current, payload.ifMatchHash(), null, null);
        }

        // hash 一致 → 快进，无冲突
        if (payload.ifMatchHash().equals(current.getContentHash())) {
            return accept(userId, path, content, current, payload.deviceId(), "ok");
        }

        // hash 不一致 → 尝试三方合并
        String base = baseContent(userId, path, payload.ifMatchHash());
        String theirs = cas.readText(current.getContentHash());
        if (theirs == null) {
            theirs = "";
        }
        ThreeWayMerge.Result merged = base != null ? ThreeWayMerge.merge(base, content, theirs) : null;
        if (merged != null && merged.clean) {
            return accept(userId, path, merged.text, current, payload.deviceId(), "merged");
        }

        // 冲突：保留服务端 theirs 为正本，mine/theirs 落冲突副本（绝不覆盖）
        String markerText = merged != null ? merged.text : fallbackMarkers(content, theirs);
        return conflict(userId, path, content, current, payload.ifMatchHash(), base, markerText);
    }

    private VaultPushResult create(Long userId, String path, String content, String deviceId) {
        String hash = cas.storeText(content);
        long size = content.getBytes(StandardCharsets.UTF_8).length;
        VaultFile f = newVaultFile(userId, path, hash, size, 1, deviceId, STATUS_ACTIVE);
        fileRepo.save(f);
        versionRepo.save(newVersionRow(userId, path, 1, hash, size, deviceId));
        return new VaultPushResult("created", toFileData(path, content, hash, 1, size, f.getUpdatedAt()), null);
    }

    private VaultPushResult accept(Long userId, String path, String content, VaultFile current, String deviceId, String outcome) {
        String hash = cas.storeText(content);
        long size = content.getBytes(StandardCharsets.UTF_8).length;
        int newVersion = current.getVersion() + 1;
        current.setContentHash(hash);
        current.setSizeBytes(size);
        current.setVersion(newVersion);
        current.setStatus(STATUS_ACTIVE);
        current.setLastModifiedDeviceId(deviceId);
        fileRepo.save(current);
        versionRepo.save(newVersionRow(userId, path, newVersion, hash, size, deviceId));
        return new VaultPushResult(outcome, toFileData(path, content, hash, newVersion, size, current.getUpdatedAt()), null);
    }

    private VaultPushResult conflict(Long userId, String path, String mineContent, VaultFile current,
                                     String ifMatchHash, String base, String markerText) {
        String theirsHash = current.getContentHash();
        String theirsContent = cas.readText(theirsHash);
        if (theirsContent == null) {
            theirsContent = "";
        }
        // 冲突副本（独立路径，Obsidian 可见），内容为带标记的三方合并
        String copyPath = conflictCopyPath(path);
        String copyHash = cas.storeText(markerText);
        long copySize = markerText.getBytes(StandardCharsets.UTF_8).length;
        VaultFile copy = newVaultFile(userId, copyPath, copyHash, copySize, 1, current.getLastModifiedDeviceId(), STATUS_ACTIVE);
        fileRepo.save(copy);
        versionRepo.save(newVersionRow(userId, copyPath, 1, copyHash, copySize, current.getLastModifiedDeviceId()));

        VaultConflict c = new VaultConflict();
        c.setUserId(userId);
        c.setVaultPath(path);
        c.setMineHash(ContentHasher.sha256(mineContent));
        c.setTheirsHash(theirsHash);
        c.setConflictCopyPath(copyPath);
        c.setStatus("open");
        conflictRepo.save(c);

        return new VaultPushResult("conflict", null,
                new ConflictView(ifMatchHash, theirsHash, theirsContent, copyPath, c.getId()));
    }

    // ============================ 拉取 / 读取 / 删除 / 历史 ============================

    @Transactional(readOnly = true)
    public VaultChangesData changes(Long userId, String since, Integer limit) {
        // 游标可能为脏值（如历史 mock 残留 "mock-cursor-..." 或非法格式），解析失败时降级为从头拉取，
        // 避免客户端历史脏数据导致整条同步链路 500。
        Instant sinceInstant;
        if (since == null || since.isBlank()) {
            sinceInstant = Instant.EPOCH;
        } else {
            try {
                sinceInstant = Instant.parse(since);
            } catch (DateTimeParseException e) {
                sinceInstant = Instant.EPOCH;
            }
        }
        int size = Math.min(Math.max(limit == null ? 200 : limit, 1), 500);
        Page<VaultFile> page = fileRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(
                userId, sinceInstant, PageRequest.of(0, size));
        List<VaultChangeSummary> summaries = page.getContent().stream().map(this::toSummary).toList();
        Instant now = Instant.now();
        String nextCursor = summaries.isEmpty()
                ? now.toString()
                : page.getContent().get(page.getNumberOfElements() - 1).getUpdatedAt().toString();
        return new VaultChangesData(summaries, now.toString(), nextCursor, page.hasNext());
    }

    @Transactional(readOnly = true)
    public VaultFileData getFile(Long userId, String path) {
        VaultFile f = fileRepo.findByUserIdAndVaultPath(userId, normalize(path)).orElse(null);
        if (f == null || !STATUS_ACTIVE.equals(f.getStatus())) {
            return null;
        }
        String content = cas.readText(f.getContentHash());
        return toFileData(f.getVaultPath(), content == null ? "" : content, f.getContentHash(),
                f.getVersion(), f.getSizeBytes(), f.getUpdatedAt());
    }

    @Transactional
    public boolean delete(Long userId, String path, String deviceId) {
        VaultFile f = fileRepo.findByUserIdAndVaultPath(userId, normalize(path)).orElse(null);
        if (f == null) {
            return false;
        }
        if (STATUS_DELETED.equals(f.getStatus())) {
            return true;
        }
        int newVersion = f.getVersion() + 1;
        f.setStatus(STATUS_DELETED);
        f.setVersion(newVersion);
        f.setLastModifiedDeviceId(deviceId);
        fileRepo.save(f);
        versionRepo.save(newVersionRow(userId, f.getVaultPath(), newVersion, f.getContentHash(), f.getSizeBytes(), deviceId));
        return true;
    }

    @Transactional(readOnly = true)
    public List<VaultVersionSummary> versions(Long userId, String path, int limit) {
        int size = Math.min(Math.max(limit, 1), 100);
        Page<VaultVersion> page = versionRepo.findByUserIdAndVaultPathOrderByVersionDesc(
                userId, normalize(path), PageRequest.of(0, size));
        return page.getContent().stream()
                .map(v -> new VaultVersionSummary(v.getVersion(), v.getContentHash(), v.getSizeBytes(),
                        v.getDeviceId(), str(v.getCreatedAt())))
                .toList();
    }

    // ============================ 冲突查询 / 解决（阶段九） ============================

    /** 列出当前用户所有 open 冲突（含 theirs 内容预览）。 */
    @Transactional(readOnly = true)
    public List<ConflictItem> listConflicts(Long userId) {
        return conflictRepo.findByUserIdAndStatusOrderByCreatedAtDesc(userId, "open").stream()
                .map(c -> {
                    String theirsContent = c.getTheirsHash() == null ? "" : cas.readText(c.getTheirsHash());
                    return new ConflictItem(
                            c.getId(), c.getVaultPath(), c.getMineHash(), c.getTheirsHash(),
                            theirsContent == null ? "" : theirsContent,
                            c.getConflictCopyPath(), c.getStatus(), c.getCreatedAt());
                })
                .toList();
    }

    /**
     * 解决冲突。
     * <ul>
     *   <li>{@code keepMine} —— 以客户端 content 强制覆盖服务端正本（写新版本），merged_hash = 新 hash。</li>
     *   <li>{@code keepTheirs} —— 服务端正本不动，merged_hash = theirs_hash。</li>
     * </ul>
     * 冲突标记 resolved。归属校验失败（不存在/非本人）返回 null。
     *
     * @return 更新后的文件正文（keepMine）/ null（keepTheirs 或无权）
     */
    @Transactional
    public VaultFileData resolveConflict(Long userId, Long conflictId, ConflictResolveRequest req) {
        Optional<VaultConflict> opt = conflictRepo.findByIdAndUserId(conflictId, userId);
        if (opt.isEmpty()) {
            return null;
        }
        VaultConflict c = opt.get();
        String path = c.getVaultPath();
        String deviceId = null;
        VaultFile current = fileRepo.findByUserIdAndVaultPath(userId, path).orElse(null);

        String mergedHash;
        if ("keepMine".equalsIgnoreCase(req.strategy())) {
            String mineContent = req.content() == null ? "" : req.content();
            // 以本机内容覆盖服务端正本（写新版本）。accept 返回 VaultPushResult，取 data。
            VaultPushResult res = accept(userId, path, mineContent,
                    current != null ? current : newPlaceholder(userId, path),
                    deviceId, "ok");
            VaultFileData data = res.data();
            mergedHash = data == null ? ContentHasher.sha256(mineContent) : data.contentHash();
            c.setMergedHash(mergedHash);
            c.setStatus("resolved");
            conflictRepo.save(c);
            return data;
        } else {
            // keepTheirs：正本不动，标 resolved，merged_hash = theirs。
            mergedHash = c.getTheirsHash();
            c.setMergedHash(mergedHash);
            c.setStatus("resolved");
            conflictRepo.save(c);
            return current == null ? null : getFile(userId, path);
        }
    }

    /** 无正本时的占位（理论上冲突必有正本，兜底用）。 */
    private VaultFile newPlaceholder(Long userId, String path) {
        VaultFile f = new VaultFile();
        f.setUserId(userId);
        f.setVaultPath(path);
        f.setContentHash("");
        f.setVersion(0);
        f.setStatus(STATUS_ACTIVE);
        return f;
    }

    // ============================ helpers ============================

    private String baseContent(Long userId, String path, String hash) {
        if (hash == null || !versionRepo.existsByUserIdAndVaultPathAndContentHash(userId, path, hash)) {
            return null;
        }
        return cas.readText(hash);
    }

    private VaultFile newVaultFile(Long userId, String path, String hash, long size, int version, String deviceId, String status) {
        VaultFile f = new VaultFile();
        f.setUserId(userId);
        f.setVaultPath(path);
        f.setContentHash(hash);
        f.setSizeBytes(size);
        f.setVersion(version);
        f.setStatus(status);
        f.setLastModifiedDeviceId(deviceId);
        return f;
    }

    private VaultVersion newVersionRow(Long userId, String path, int version, String hash, long size, String deviceId) {
        VaultVersion v = new VaultVersion();
        v.setUserId(userId);
        v.setVaultPath(path);
        v.setVersion(version);
        v.setContentHash(hash);
        v.setSizeBytes(size);
        v.setDeviceId(deviceId);
        return v;
    }

    private VaultChangeSummary toSummary(VaultFile f) {
        return new VaultChangeSummary(f.getVaultPath(), f.getContentHash(), f.getVersion(),
                str(f.getUpdatedAt()), f.getStatus(), f.getSizeBytes());
    }

    private VaultFileData toFileData(String path, String content, String hash, int version, long size, Instant updatedAt) {
        return new VaultFileData(path, content, hash, version, str(updatedAt), size);
    }

    private String conflictCopyPath(String path) {
        String ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss"));
        String base = path.toLowerCase().endsWith(".md") ? path.substring(0, path.length() - 3) : path;
        return base + ".conflict-" + ts + ".md";
    }

    private String fallbackMarkers(String ours, String theirs) {
        return "<<<<<<< mine\n" + (ours == null ? "" : ours)
                + "\n=======\n" + (theirs == null ? "" : theirs) + "\n>>>>>>> theirs";
    }

    private String normalize(String path) {
        if (path == null) {
            throw new IllegalArgumentException("vaultPath 不能为空");
        }
        String p = path.trim().replace('\\', '/');
        while (p.startsWith("/")) {
            p = p.substring(1);
        }
        if (p.isEmpty()) {
            throw new IllegalArgumentException("vaultPath 不能为空");
        }
        if (p.contains("..") || p.contains(":")) {
            throw new IllegalArgumentException("vaultPath 非法：" + path);
        }
        return p;
    }

    private String str(Instant instant) {
        return instant == null ? null : instant.toString();
    }
}
