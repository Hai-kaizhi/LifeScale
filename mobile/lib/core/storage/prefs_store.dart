import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../util/id_util.dart';

/// 非敏感本地偏好：deviceId（一次性生成，永久稳定）、用户摘要、同步游标。
///
/// 与桌面端 localStorage 键名对齐：
/// - `lifescale.device.id`、`lifescale.auth.user`、`lifescale.sync.lastCursor`。
class PrefsStore {
  PrefsStore(this._prefs);

  static const _kDeviceId = 'lifescale.device.id';
  static const _kUser = 'lifescale.auth.user';
  static const _kLastCursor = 'lifescale.sync.lastCursor';

  final SharedPreferences _prefs;

  /// 读取或首次生成 deviceId（UUID v4），后续稳定不变。
  String getOrCreateDeviceId() {
    var id = _prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = IdUtil.newId();
      _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  UserSummary? getUser() {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(UserSummary user) =>
      _prefs.setString(_kUser, jsonEncode(user.toJson()));

  Future<void> clearUser() => _prefs.remove(_kUser);

  String? getLastCursor() {
    final raw = _prefs.getString(_kLastCursor);
    if (raw == null || raw.isEmpty) return null;
    // 防御：历史 mock 残留（如 "mock-cursor-..."）或其它非法游标，必须能被 DateTime 解析，
    // 否则当作没有游标（让后端从头拉取），避免非法 since 触发 500。
    try {
      DateTime.parse(raw);
    } catch (_) {
      return null;
    }
    return raw;
  }
  Future<void> setLastCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) {
      return _prefs.remove(_kLastCursor);
    }
    return _prefs.setString(_kLastCursor, cursor);
  }
}

/// 用户摘要（冷启动 UI 占位，避免 loading 闪烁）。
class UserSummary {
  const UserSummary({required this.id, required this.username, this.email});

  final int id;
  final String username;
  final String? email;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: (json['id'] as num).toInt(),
    username: json['username'] as String,
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    if (email != null) 'email': email,
  };
}
