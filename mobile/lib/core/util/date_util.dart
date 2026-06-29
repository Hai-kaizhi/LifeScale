/// 日期格式化工具（标题「YYYY年M月D日 周X」与 ISO 日期）。
class DateUtil {
  const DateUtil._();

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 今天 ISO 日期 `YYYY-MM-DD`（用于 Daily 文件名与 `createdAt` 派生）。
  static String todayIso([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Daily 文档标题，如「2026年6月17日 周三」。
  static String dailyTitle([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}年${d.month}月${d.day}日 ${_weekdays[d.weekday - 1]}';
  }

  /// 解析 YYYY-MM-DD 字符串为 DateTime（仅日期，不含时分）。非法返回 null。
  static DateTime? parseIso(String? date) {
    if (date == null || date.isEmpty) return null;
    return DateTime.tryParse('${date}T00:00:00');
  }

  /// 任意 DateTime → YYYY-MM-DD。
  static String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 将 YYYY-MM-DD 字符串偏移 [days] 天，返回新的 YYYY-MM-DD。入参非法返回 null。
  static String? plusDays(String date, int days) {
    final base = parseIso(date);
    if (base == null) return null;
    return iso(base.add(Duration(days: days)));
  }
}
