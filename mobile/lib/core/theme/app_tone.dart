/// 时段色调枚举。
///
/// 全 App 的色调真相统一收敛到 [AppTone]，不再在各个 feature controller
/// 内重复持有 tone 状态。三套预设：早晨 / 下午 / 夜晚。
///
/// 新增第 4、5 套主题时，只需在本枚举加一项，并在 [ToneTheme.of] 补一套
/// [ToneTokens]，UI 控件（如 ToneSegmentedControl）会自动遍历展示。
enum AppTone {
  morning('早晨'),
  afternoon('下午'),
  night('夜晚');

  const AppTone(this.label);

  /// 用于切换控件与设置的中文展示名。
  final String label;

  /// 是否为暗色基调（决定全局 [Brightness]、Material 组件配色走向）。
  ///
  /// 早晨 / 下午为浅色基调，夜晚为暗色基调。
  bool get isDark => this == AppTone.night;
}
