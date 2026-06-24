/// 笔记摘要（列表项）。
class NoteSummary {
  const NoteSummary({
    required this.vaultPath,
    required this.title,
    required this.mtime, // ISO-8601
    required this.version,
    required this.syncedHash,
  });

  final String vaultPath;
  final String title; // 文件名（不含 .md）
  final String mtime;
  final int version;
  final String? syncedHash;

  /// 同步状态：本地有 syncedHash 且与云端一致 = 已同步；否则待同步。
  bool get synced => syncedHash != null && syncedHash!.isNotEmpty;

  /// 相对时间描述（粗略）。
  String get relativeTime => _relative(mtime);

  String _relative(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final now = DateTime.now().toUtc();
    final utc = t.toUtc();
    final diff = now.difference(utc);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

/// 笔记加载状态。
enum NotesLoadStatus { loading, ready, empty, error }

class NotesState {
  const NotesState({
    this.status = NotesLoadStatus.loading,
    this.notes = const [],
    this.filter = '',
    this.message,
  });

  final NotesLoadStatus status;
  final List<NoteSummary> notes;
  final String filter;
  final String? message;

  /// 经搜索过滤后的列表。
  List<NoteSummary> get filtered {
    if (filter.isEmpty) return notes;
    final f = filter.toLowerCase();
    return notes
        .where((n) =>
            n.title.toLowerCase().contains(f) ||
            n.vaultPath.toLowerCase().contains(f))
        .toList();
  }

  NotesState copyWith({
    NotesLoadStatus? status,
    List<NoteSummary>? notes,
    String? filter,
    bool clearFilter = false,
    String? message,
    bool clearMessage = false,
  }) =>
      NotesState(
        status: status ?? this.status,
        notes: notes ?? this.notes,
        filter: clearFilter ? '' : (filter ?? this.filter),
        message: clearMessage ? null : message ?? this.message,
      );
}
