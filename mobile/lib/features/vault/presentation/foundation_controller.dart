import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../vault_providers.dart';
import 'foundation_state.dart';

/// Smoke 页控制器：驱动第 0 步的 4 个验收闸门。
class FoundationController extends Notifier<FoundationState> {
  @override
  FoundationState build() => const FoundationState();

  /// 闸门 1：登录获取 token。
  Future<void> login(String username, String password) async {
    state = state.copyWith(busy: true, loginMessage: '登录中…');
    try {
      final err = await ref
          .read(authControllerProvider.notifier)
          .login(username, password);
      state = state.copyWith(
        busy: false,
        loginMessage: err == null ? '登录成功 ✓' : '登录失败：$err',
      );
    } catch (e) {
      state = state.copyWith(busy: false, loginMessage: '登录失败：$e');
    }
  }

  /// 闸门 2：注册设备。
  Future<void> registerDevice() async {
    state = state.copyWith(busy: true, deviceMessage: '注册中…');
    final res = await ref
        .read(authControllerProvider.notifier)
        .registerDevice();
    switch (res) {
      case ApiSuccess(:final data):
        state = state.copyWith(
          busy: false,
          deviceMessage: '注册成功 ✓ 设备 ID：${data.id ?? data.deviceId}',
        );
      case ApiFailure(:final message):
        state = state.copyWith(busy: false, deviceMessage: '注册失败：$message');
    }
  }

  /// 闸门 3：调用 /api/vault/changes。
  Future<void> callChanges() async {
    state = state.copyWith(busy: true, changesMessage: '请求中…');
    final result = await ref.read(vaultRepositoryProvider).changes(limit: 50);
    switch (result) {
      case ApiSuccess(:final data):
        final json = jsonEncode(data.toJson());
        final preview = json.length > 400 ? '${json.substring(0, 400)}…' : json;
        state = state.copyWith(
          busy: false,
          changesMessage: 'changes: ${data.changes.length} 条\n$preview',
        );
      case ApiFailure(:final message):
        state = state.copyWith(busy: false, changesMessage: '失败：$message');
    }
  }

  /// 闸门 4：缓存示例 Markdown 到本地沙盒。
  Future<void> cacheSample() async {
    state = state.copyWith(busy: true, cacheMessage: '写入中…');
    try {
      final path = await ref
          .read(vaultRepositoryProvider)
          .cacheSampleMarkdown();
      state = state.copyWith(busy: false, cacheMessage: '已缓存 ✓\n$path');
    } catch (e) {
      state = state.copyWith(busy: false, cacheMessage: '失败：$e');
    }
  }
}

final foundationControllerProvider =
    NotifierProvider<FoundationController, FoundationState>(
      FoundationController.new,
    );
