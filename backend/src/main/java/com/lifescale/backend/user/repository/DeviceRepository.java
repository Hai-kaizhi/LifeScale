package com.lifescale.backend.user.repository;

import com.lifescale.backend.user.entity.Device;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * 设备注册仓储。
 */
public interface DeviceRepository extends JpaRepository<Device, Long> {

    Optional<Device> findByUserIdAndDeviceId(Long userId, String deviceId);

    List<Device> findByUserIdOrderByUpdatedAtDesc(Long userId);
}
