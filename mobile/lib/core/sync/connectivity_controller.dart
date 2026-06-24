import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import 'sync_engine.dart';
import 'sync_status_controller.dart';

/// 网络连接状态（阶段九）。
enum ConnectivityState { online, offline }

/// 网络监听 + 自动补推调度。
///
/// - 监听 `connectivity_plus` 的 `onConnectivityChanged`。
/// - 从 offline → online 时触发 [SyncEngine.flushPending] 并刷新同步状态。
/// - 防抖：online 后延迟 1.5s 再补推（避免网络刚恢复抖动）。
class ConnectivityController extends Notifier<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;

  @override
  ConnectivityState build() {
    _initListener();
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    return ConnectivityState.online; // 乐观初值，监听回调会校正
  }

  void _initListener() {
    final connectivity = Connectivity();
    // 先校正一次当前状态。
    connectivity.checkConnectivity().then((results) => _apply(results));
    _sub = connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final online = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.bluetooth,
    );
    final next = online ? ConnectivityState.online : ConnectivityState.offline;
    final wasOffline = state == ConnectivityState.offline;
    if (state != next) {
      state = next;
    }
    // offline → online：延迟补推（防抖，网络刚恢复可能抖动）。
    if (wasOffline && next == ConnectivityState.online) {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    if (!ref.read(cloudSyncEnabledProvider)) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () async {
      try {
        if (!ref.read(cloudSyncEnabledProvider)) return;
        final engine = ref.read(syncEngineProvider);
        final result = await engine.flushPending();
        if (result.hadActivity) {
          // 刷新全局同步状态计数（待同步/冲突）。
          ref.read(syncStatusControllerProvider.notifier).refresh();
        }
      } catch (e) {
        debugPrint('⚠️ 网络恢复补推失败：$e');
      }
    });
  }

  /// 手动触发一次补推（回前台 / 用户点击时调用）。
  Future<void> triggerFlush() async {
    if (!ref.read(cloudSyncEnabledProvider)) return;
    if (state != ConnectivityState.online) return;
    _scheduleFlush();
  }
}

final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );
