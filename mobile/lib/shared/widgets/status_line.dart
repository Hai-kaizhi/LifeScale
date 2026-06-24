import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';

/// 状态行：展示鉴权状态、用户、deviceId、API base、是否模拟器目标。
/// 便于在真机/模拟器上一眼核对当前网络配置是否正确。
class StatusLine extends ConsumerWidget {
  const StatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final statusName = switch (auth.status) {
      AuthStatus.loading => 'loading',
      AuthStatus.local => 'local（未登录）',
      AuthStatus.authenticated => 'authenticated',
    };
    final user = auth.user?.username ?? '—';
    final deviceId = (auth.deviceId == null || auth.deviceId!.isEmpty)
        ? '—'
        : auth.deviceId!.substring(0, 8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'auth: $statusName\nuser: $user | deviceId: $deviceId\n'
        'api: ${AppConfig.apiBaseUrl}\nemulator: ${AppConfig.isEmulator}',
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}
