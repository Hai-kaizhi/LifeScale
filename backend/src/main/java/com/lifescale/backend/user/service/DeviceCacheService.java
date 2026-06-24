package com.lifescale.backend.user.service;

import com.lifescale.backend.user.dto.DeviceDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;
import java.util.function.Supplier;

/**
 * 设备列表短期缓存（阶段一引入的最小 Redis 用法）。
 * <p>
 * 职责边界：仅缓存「读多写少」的设备列表；设备注册（写）时立即失效对应 key。
 * Redis 不可用时透明降级直查库，不抛异常、不阻塞主流程。
 */
@Service
public class DeviceCacheService {

    private static final Logger log = LoggerFactory.getLogger(DeviceCacheService.class);
    private static final String KEY_PREFIX = "lifescale:auth:devices:";
    private static final Duration TTL = Duration.ofMinutes(5);

    private final RedisTemplate<String, Object> redisTemplate;

    @Autowired
    public DeviceCacheService(@Qualifier("redisTemplate") RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /**
     * 读设备列表：命中缓存直接返回；未命中则调用 loader 查库并回写缓存。
     * 任意 Redis 异常均降级为 loader 直查，保证可用性。
     */
    @SuppressWarnings("unchecked")
    public List<DeviceDTO> getOrLoad(Long userId, Supplier<List<DeviceDTO>> loader) {
        if (userId == null) {
            return loader.get();
        }
        String key = key(userId);
        try {
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof List<?> list) {
                return (List<DeviceDTO>) list;
            }
        } catch (Exception e) {
            log.warn("设备列表缓存读取失败，降级直查库：userId={} err={}", userId, e.getMessage());
            return loader.get();
        }
        List<DeviceDTO> fresh = loader.get();
        try {
            redisTemplate.opsForValue().set(key, fresh, TTL);
        } catch (Exception e) {
            log.warn("设备列表缓存写入失败（不影响主流程）：userId={} err={}", userId, e.getMessage());
        }
        return fresh;
    }

    /** 设备注册/更新后失效该用户的设备列表缓存。 */
    public void evict(Long userId) {
        if (userId == null) {
            return;
        }
        try {
            redisTemplate.delete(key(userId));
        } catch (Exception e) {
            log.warn("设备列表缓存失效失败（不影响主流程）：userId={} err={}", userId, e.getMessage());
        }
    }

    private String key(Long userId) {
        return KEY_PREFIX + userId;
    }
}
