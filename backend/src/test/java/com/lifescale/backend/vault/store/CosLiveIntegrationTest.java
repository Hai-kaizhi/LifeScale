package com.lifescale.backend.vault.store;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.model.COSObjectInputStream;
import com.qcloud.cos.model.GetObjectRequest;
import com.qcloud.cos.model.ObjectMetadata;
import com.qcloud.cos.model.PutObjectRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 腾讯云 COS 真实往返集成测试（连通性自测）。
 * <p>
 * 默认跳过——仅当环境变量 {@code LIFESCALE_COS_LIVE_TEST=true} 且 {@code LIFESCALE_COS_*}
 * 全部就位时才运行，避免污染常规 {@code mvn test}。运行命令：
 * <pre>
 * LIFESCALE_COS_LIVE_TEST=true mvn -Dtest=CosLiveIntegrationTest test
 * </pre>
 * <p>
 * 覆盖完整链路：putObject → doesObjectExist → getObject → getObjectMetadata → deleteObject，
 * 验证凭据、桶名、地域、子账号权限（PutObject/GetObject/HeadObject/DeleteObject）全部正确。
 */
@EnabledIfEnvironmentVariable(named = "LIFESCALE_COS_LIVE_TEST", matches = "true")
class CosLiveIntegrationTest {

    private static final Logger log = LoggerFactory.getLogger(CosLiveIntegrationTest.class);

    private COSClient cosClient;
    private String bucket;
    private String prefix;
    private String testKey;

    @BeforeEach
    void setUp() {
        String secretId = System.getenv("LIFESCALE_COS_SECRET_ID");
        String secretKey = System.getenv("LIFESCALE_COS_SECRET_KEY");
        String region = System.getenv("LIFESCALE_COS_REGION");
        bucket = System.getenv("LIFESCALE_COS_BUCKET");
        prefix = envOrDefault("LIFESCALE_COS_PREFIX", "att");

        log.info("COS 连通性自测启动：bucket={}, region={}, prefix={}", bucket, region, prefix);
        assertThat(secretId).as("LIFESCALE_COS_SECRET_ID 未设置").isNotBlank();
        assertThat(secretKey).as("LIFESCALE_COS_SECRET_KEY 未设置").isNotBlank();
        assertThat(region).as("LIFESCALE_COS_REGION 未设置").isNotBlank();
        assertThat(bucket).as("LIFESCALE_COS_BUCKET 未设置").isNotBlank();

        com.qcloud.cos.auth.COSCredentials cred =
                new com.qcloud.cos.auth.BasicCOSCredentials(secretId, secretKey);
        com.qcloud.cos.ClientConfig cfg = new com.qcloud.cos.ClientConfig(new com.qcloud.cos.region.Region(region));
        cosClient = new COSClient(cred, cfg);

        // 用唯一 key 避免并发/残留冲突，前缀对齐生产路径 att/<hash前2位>/<hash>。
        String rand = UUID.randomUUID().toString().replace("-", "");
        testKey = prefix + "/t" + rand.substring(0, 2) + "/livetest-" + rand;
    }

    @AfterEach
    void tearDown() {
        if (cosClient != null && testKey != null) {
            try {
                cosClient.deleteObject(bucket, testKey);
                log.info("COS 自测清理完成：已删除 {}", testKey);
            } catch (Exception e) {
                log.warn("COS 自测清理失败（不影响结论）：{}", e.getMessage());
            }
            cosClient.shutdown();
        }
    }

    @Test
    @DisplayName("COS 完整往返：上传 → 存在性检查 → 下载 → 元数据 → 删除")
    void cosRoundTrip() {
        byte[] payload = "lifescale-cos-live-test-你好世界".getBytes(StandardCharsets.UTF_8);

        // ① 上传（校验 PutObject 权限 + 凭据有效性）
        ObjectMetadata meta = new ObjectMetadata();
        meta.setContentLength(payload.length);
        meta.setContentType("application/octet-stream");
        cosClient.putObject(new PutObjectRequest(bucket, testKey,
                new ByteArrayInputStream(payload), meta));
        log.info("✅ 上传成功：{}", testKey);

        // ② 存在性检查（校验 HeadObject 权限）
        boolean exists = cosClient.doesObjectExist(bucket, testKey);
        assertThat(exists).as("上传后应能 HEAD 到对象").isTrue();
        log.info("✅ 存在性检查通过");

        // ③ 下载（校验 GetObject 权限 + 内容一致）
        byte[] downloaded;
        try (com.qcloud.cos.model.COSObject obj = cosClient.getObject(new GetObjectRequest(bucket, testKey));
             COSObjectInputStream is = obj.getObjectContent()) {
            downloaded = is.readAllBytes();
        } catch (Exception e) {
            // CosServiceException 是 CosClientException 的子类，统一捕获即可
            throw new AssertionError("COS 下载失败：" + e.getMessage(), e);
        }
        assertThat(downloaded).isEqualTo(payload);
        log.info("✅ 下载成功，内容一致（{} 字节）", downloaded.length);

        // ④ 元数据（校验大小）
        ObjectMetadata head = cosClient.getObjectMetadata(bucket, testKey);
        assertThat(head.getContentLength()).isEqualTo(payload.length);
        log.info("✅ 元数据一致：size={}", head.getContentLength());

        // ⑤ 删除（校验 DeleteObject 权限 + 桶可写）
        cosClient.deleteObject(bucket, testKey);
        assertThat(cosClient.doesObjectExist(bucket, testKey))
                .as("删除后 HEAD 应为 false").isFalse();
        log.info("✅ 删除成功");
    }

    private static String envOrDefault(String name, String def) {
        String v = System.getenv(name);
        return (v == null || v.isBlank()) ? def : v;
    }
}
