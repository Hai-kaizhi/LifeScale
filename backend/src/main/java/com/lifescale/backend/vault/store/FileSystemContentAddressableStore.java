package com.lifescale.backend.vault.store;

import com.lifescale.backend.common.util.ContentHasher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Optional;

/**
 * 文件系统 CAS：&lt;root&gt;/&lt;hash前2位&gt;/&lt;hash&gt;.md，原子写（临时文件 + rename）。
 * 写盘失败抛运行时异常（vault 写入事务会回滚，绝不落脏数据）。
 */
@Component
public class FileSystemContentAddressableStore implements ContentAddressableStore {

    private static final Logger log = LoggerFactory.getLogger(FileSystemContentAddressableStore.class);

    private final Path root;

    public FileSystemContentAddressableStore(@Value("${lifescale.storage.cas-root:./data/vault-cas}") String root) {
        this.root = Paths.get(root);
    }

    @Override
    public String storeText(String content) {
        String safe = content == null ? "" : content;
        String hash = ContentHasher.sha256(safe);
        store(hash, safe.getBytes(StandardCharsets.UTF_8));
        return hash;
    }

    @Override
    public synchronized void store(String hash, byte[] bytes) {
        try {
            Path file = pathFor(hash);
            if (Files.exists(file)) {
                return;
            }
            Files.createDirectories(file.getParent());
            Path tmp = Files.createTempFile(file.getParent(), ".cas-", ".tmp");
            Files.write(tmp, bytes);
            try {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } catch (IOException atomicUnsupported) {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new RuntimeException("CAS 写入失败: " + hash, e);
        }
    }

    @Override
    public byte[] read(String hash) {
        if (hash == null) {
            return null;
        }
        try {
            Path file = pathFor(hash);
            return Files.exists(file) ? Files.readAllBytes(file) : null;
        } catch (IOException e) {
            log.warn("CAS 读取失败：hash={}, err={}", hash, e.getMessage());
            return null;
        }
    }

    @Override
    public String readText(String hash) {
        byte[] b = read(hash);
        return b == null ? null : new String(b, StandardCharsets.UTF_8);
    }

    @Override
    public boolean exists(String hash) {
        return hash != null && Files.exists(pathFor(hash));
    }

    // ---- 附件（隔离 att/ 子树，无后缀，避免与正文 .md CAS 混淆）----

    @Override
    public synchronized void storeAttachment(String hash, byte[] bytes) {
        try {
            Path file = pathForAttachment(hash);
            if (Files.exists(file)) {
                return;
            }
            Files.createDirectories(file.getParent());
            Path tmp = Files.createTempFile(file.getParent(), ".att-", ".tmp");
            Files.write(tmp, bytes);
            try {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } catch (IOException atomicUnsupported) {
                Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new RuntimeException("CAS 附件写入失败: " + hash, e);
        }
    }

    @Override
    public byte[] readAttachment(String hash) {
        if (hash == null) {
            return null;
        }
        try {
            Path file = pathForAttachment(hash);
            return Files.exists(file) ? Files.readAllBytes(file) : null;
        } catch (IOException e) {
            log.warn("CAS 附件读取失败：hash={}, err={}", hash, e.getMessage());
            return null;
        }
    }

    @Override
    public boolean existsAttachment(String hash) {
        return hash != null && Files.exists(pathForAttachment(hash));
    }

    /**
     * 附件下载资源（磁盘 CAS）：返回 filePath（Controller 包 FileSystemResource，
     * Spring 自动支持 Range/206）。hash 为空返回 empty；不做存在性校验。
     */
    @Override
    public Optional<AttachmentResource> attachmentResource(String hash) {
        if (hash == null) {
            return Optional.empty();
        }
        Path file = pathForAttachment(hash);
        long size;
        try {
            size = Files.exists(file) ? Files.size(file) : 0L;
        } catch (IOException e) {
            log.warn("磁盘附件大小读取失败：hash={}, err={}", hash, e.getMessage());
            size = 0L;
        }
        return Optional.of(AttachmentResource.ofFile(size, file));
    }

    @Override
    public String storageLocationTag() {
        return "local";
    }

    private Path pathFor(String hash) {
        String prefix = hash.length() >= 2 ? hash.substring(0, 2) : "00";
        return root.resolve(prefix).resolve(hash + ".md");
    }

    private Path pathForAttachment(String hash) {
        String prefix = hash.length() >= 2 ? hash.substring(0, 2) : "00";
        return root.resolve("att").resolve(prefix).resolve(hash);
    }
}
