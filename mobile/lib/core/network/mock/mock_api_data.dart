import '../../util/crypto_util.dart';
import '../../util/date_util.dart';
import 'dart:typed_data';

class MockVaultFile {
  const MockVaultFile({
    required this.vaultPath,
    required this.content,
    required this.version,
    required this.serverMtime,
    this.status = 'active',
  });

  final String vaultPath;
  final String content;
  final int version;
  final String serverMtime;
  final String status;

  String get contentHash => CryptoUtil.sha256Hex(content);
  int get size => content.length;
}

abstract final class MockApiData {
  static const userId = 10001;
  static const username = 'lifescale';
  static const email = 'lifescale@example.com';
  static const token = 'mock.jwt.phase1.lifescale';
  static const serverTime = '2026-06-18T09:41:00.000Z';
  static const nextCursor = 'mock-cursor-2026-06-18T09:41:00Z';

  /// 阶段八：demo 附件 SHA-256（固定值，与下方 demoPngBytes 对应）。
  /// 笔记 Markdown 中引用 `attachments/<此hash>.png`，mock 下载返回 demoPngBytes。
  static const demoAttachmentHash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// 阶段八：1x1 蓝色 PNG 字节（mock 附件下载返回体，让图片渲染为实图而非占位）。
  /// 这是标准的最小合法 PNG（8 字节签名 + IHDR + IDAT + IEND），蓝色像素。
  static final Uint8List demoPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    0x00, 0x00, 0x00, 0x01, // width=1
    0x00, 0x00, 0x00, 0x01, // height=1
    0x08, 0x06, 0x00, 0x00, 0x00, // bit depth 8, color type 6 (RGBA)
    0x1F, 0x15, 0xC4, 0x89, // CRC
    0x00, 0x00, 0x00, 0x0A, // IDAT length
    0x49, 0x44, 0x41, 0x54, // "IDAT"
    0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, // zlib stream (1 blue RGBA pixel)
    0x0D, 0x0A, 0xDB, 0xB2, // CRC
    0x00, 0x00, 0x00, 0x00, // IEND length
    0x49, 0x45, 0x4E, 0x44, // "IEND"
    0xAE, 0x42, 0x60, 0x82, // CRC
  ]);

  static String get todayDate => DateUtil.todayIso();
  static String get todayPath => 'Daily/$todayDate.md';

  static String get todayMarkdown => '''# ${DateUtil.dailyTitle()}

## 今日重点
- 完成产品方案初稿 <!-- focus -->
- 09:30-10:30 完成产品方案初稿（工作） <!-- sid:s1 -->

## 今日日程
- [x] 09:30-10:30 完成产品方案初稿（工作） <!-- sid:s1 -->
- [x] 10:45-11:30 与团队同步需求（工作） <!-- sid:s2 -->
- [x] 13:30-14:20 用户调研与分析（工作） <!-- sid:s3 -->
- [x] 15:00-16:00 撰写 PRD 文档（工作） <!-- sid:s4 -->
- [ ] 17:30-18:00 阅读 30 分钟（生活） <!-- sid:s5 -->
- [ ] 19:30-20:00 运动 30 分钟（生活） <!-- sid:s6 -->

### 时间记录
- 07:30-08:00 起床（生活） <!-- sid:s7 -->
- 08:30-09:00 阅读 30 分钟（生活） <!-- sid:s8 -->
- 11:00-11:30 同步需求（工作） <!-- sid:s9 -->
- 12:30-13:10 午休（生活） <!-- sid:s10 -->

## 快速记录
- 09:20 今天先把移动端登录链路跑顺 <!-- qn:q1 -->
- 14:05 下午保持深度工作，减少上下文切换 <!-- qn:q2 -->

## 今日复盘
### 今天我做成了什么？ <!-- rv:r1 -->
  完成产品方案初稿，并把同步初始化链路梳理清楚

### 今天我学到了什么？ <!-- rv:r2 -->
  移动端先用缓存预览能更稳地承接桌面端内容

### 今天我遇到了什么困难？ <!-- rv:r3 -->
  阶段边界需要克制，先让同步闭环扎实

### 明天我可以如何做得更好？ <!-- rv:r4 -->
  保持小步推进，每完成一段就验证一次
''';

  static const recentVaultMarkdown = '''# 移动端 Phase 1 同步说明

这是一篇从云端 Vault 拉取到 App 沙盒缓存的最近编辑文件。

- 登录后注册当前设备
- 拉取云端变更摘要
- 下载 Daily 与最近编辑 Vault 文件
- 初始化本地 sync_state

## 阶段八：附件演示

下方图片按 `attachments/<hash>.<ext>` 内容寻址引用，首次打开时懒拉取：

![](attachments/$demoAttachmentHash.png)
''';

  static List<MockVaultFile> files() => [
    MockVaultFile(
      vaultPath: todayPath,
      content: todayMarkdown,
      version: 7,
      serverMtime: '2026-06-18T09:32:00.000Z',
    ),
    const MockVaultFile(
      vaultPath: 'Notes/移动端 Phase 1 同步说明.md',
      content: recentVaultMarkdown,
      version: 3,
      serverMtime: '2026-06-17T21:16:00.000Z',
    ),
  ];
}
