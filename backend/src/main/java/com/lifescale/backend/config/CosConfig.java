package com.lifescale.backend.config;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.ClientConfig;
import com.qcloud.cos.auth.BasicCOSCredentials;
import com.qcloud.cos.auth.COSCredentials;
import com.qcloud.cos.region.Region;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 腾讯云 COS 客户端配置（P0-10）。
 * 装配条件：lifescale.storage.cos.bucket 非空。本地开发不配置 bucket → 不装配 → 回退磁盘 CAS。
 */
@Configuration
@ConditionalOnProperty(prefix = "lifescale.storage.cos", name = "bucket")
public class CosConfig {

    @Bean(destroyMethod = "shutdown")
    public COSClient cosClient(
            @Value("${lifescale.storage.cos.secret-id}") String secretId,
            @Value("${lifescale.storage.cos.secret-key}") String secretKey,
            @Value("${lifescale.storage.cos.region}") String region) {
        COSCredentials cred = new BasicCOSCredentials(secretId, secretKey);
        ClientConfig clientConfig = new ClientConfig(new Region(region));
        clientConfig.setConnectionTimeout(5000);
        clientConfig.setSocketTimeout(30000);   // 读取超时（SDK 5.6.x 为 setSocketTimeout，非 setReadTimeout）
        clientConfig.setMaxConnectionsCount(100);
        return new COSClient(cred, clientConfig);
    }
}
