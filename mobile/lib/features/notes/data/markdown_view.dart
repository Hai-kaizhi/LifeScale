import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../attachments/data/attachment_service.dart';
import '../../attachments/domain/attachment_ref.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';

/// 轻量 Markdown 渲染器（纯 Flutter Widget，无第三方依赖）。
///
/// 覆盖笔记常见语法：
/// - 标题 `#`~`######`
/// - 无序/有序列表 `- `/`* `/`1. `
/// - 任务列表 `- [x]`/`- [ ]`
/// - 引用 `>`
/// - 代码块 ``` ``` ```
/// - 分隔线 `---`
/// - 段落（含粗体 `**`、行内代码 `` ` ``、斜体 `*`）
/// - 图片 `![alt](attachments/<hash>.<ext>)`（阶段八：附件懒拉取，需传入 [attachmentService]）
///
/// 不支持的行原样显示为文本，保证不丢内容。复杂表格/嵌套不做精细处理。
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.markdown,
    this.tone = TodayTone.night,
    this.attachmentService,
  });

  final String markdown;
  final TodayTone tone;

  /// 附件懒拉取服务；为 null 时图片块退化为占位提示（不崩、不阻塞渲染）。
  final AttachmentService? attachmentService;

  @override
  Widget build(BuildContext context) {
    final tokens = Phase1Theme.of(tone);
    final blocks = _parseBlocks(markdown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks) _renderBlock(b, tokens),
      ],
    );
  }

  // ============================ 解析 ============================

  List<_Block> _parseBlocks(String md) {
    final lines = md.split(RegExp(r'\r?\n'));
    final blocks = <_Block>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // 空行跳过。
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 代码块 ```。
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++; // 跳过结束 ```
        blocks.add(_Block(_BlockType.code, buf.join('\n'), lang: lang));
        continue;
      }

      // 分隔线。
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(const _Block(_BlockType.divider, ''));
        i++;
        continue;
      }

      // 图片 ![alt](url)：独占一行，仅识别 attachments/<hash>.<ext> 引用（阶段八）。
      final img = _parseImageLine(trimmed);
      if (img != null) {
        blocks.add(_Block(_BlockType.image, '',
            imageHash: img.hash, imageExt: img.ext, imageAlt: img.alt));
        i++;
        continue;
      }

      // 标题 # ~ ######。
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (h != null) {
        final level = h.group(1)!.length;
        blocks.add(_Block(_BlockType.heading, h.group(2)!, level: level));
        i++;
        continue;
      }

      // 任务列表 - [x] / - [ ]。
      final task = RegExp(r'^[-*+]\s+\[([xX ])\]\s+(.*)$').firstMatch(trimmed);
      if (task != null) {
        final items = <_TaskItem>[];
        while (i < lines.length) {
          final t =
              RegExp(r'^[-*+]\s+\[([xX ])\]\s+(.*)$').firstMatch(lines[i].trim());
          if (t == null) break;
          items.add(_TaskItem(
            done: t.group(1)!.toLowerCase() == 'x',
            text: t.group(2)!,
          ));
          i++;
        }
        blocks.add(_Block(_BlockType.taskList, '', tasks: items));
        continue;
      }

      // 引用 >。
      if (trimmed.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buf.add(lines[i].trim().substring(1).trim());
          i++;
        }
        blocks.add(_Block(_BlockType.quote, buf.join('\n')));
        continue;
      }

      // 无序列表 - / *。
      if (RegExp(r'^[-*+]\s+').hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length &&
            RegExp(r'^[-*+]\s+').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^[-*+]\s+'), ''));
          i++;
        }
        blocks.add(_Block(_BlockType.unorderedList, '', listItems: items));
        continue;
      }

      // 有序列表 1.
      if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length &&
            RegExp(r'^\d+\.\s+').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^\d+\.\s+'), ''));
          i++;
        }
        blocks.add(_Block(_BlockType.orderedList, '', listItems: items));
        continue;
      }

      // 段落（连续非空非特殊行合并）。
      final buf = <String>[trimmed];
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_isBlockStart(lines[i].trim())) {
        buf.add(lines[i].trim());
        i++;
      }
      blocks.add(_Block(_BlockType.paragraph, buf.join(' ')));
    }
    return blocks;
  }

  bool _isBlockStart(String t) {
    if (t.startsWith('#')) return true;
    if (t.startsWith('```')) return true;
    if (t == '---' || t == '***' || t == '___') return true;
    if (t.startsWith('>')) return true;
    if (_parseImageLine(t) != null) return true;
    if (RegExp(r'^[-*+]\s+').hasMatch(t)) return true;
    if (RegExp(r'^\d+\.\s+').hasMatch(t)) return true;
    return false;
  }

  /// 解析独占一行的图片语法 `![alt](attachments/<hash>.<ext>)`。
  /// 仅识别内容寻址附件引用；其它 URL 原样作为文本。
  _ImageRef? _parseImageLine(String t) {
    final m = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(t);
    if (m == null) return null;
    final alt = m.group(1)!;
    final url = m.group(2)!.trim();
    final am = attachmentRefRegex.firstMatch(url);
    if (am == null) return null;
    return _ImageRef(hash: am.group(1)!, ext: am.group(2)!, alt: alt);
  }

  // ============================ 渲染 ============================

  Widget _renderBlock(_Block b, Phase1ToneTokens tokens) {
    switch (b.type) {
      case _BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(top: b.level == 1 ? 4 : 12, bottom: 6),
          child: Text(
            b.content,
            style: TextStyle(
              fontSize: _headingSize(b.level),
              fontWeight: FontWeight.w900,
              color: tokens.text,
              height: 1.35,
            ),
          ),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RichText(text: b.content, tokens: tokens),
        );
      case _BlockType.image:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AttachmentImage(
            hash: b.imageHash,
            ext: b.imageExt,
            alt: b.imageAlt,
            tokens: tokens,
            service: attachmentService,
          ),
        );
      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: tokens.primary.withValues(alpha: 0.06),
            border: Border(
              left: BorderSide(color: tokens.primary, width: 3),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _RichText(text: b.content, tokens: tokens),
        );
      case _BlockType.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFFF5F5F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            b.content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: tokens.text,
            ),
          ),
        );
      case _BlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: tokens.muted.withValues(alpha: 0.3)),
        );
      case _BlockType.unorderedList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in b.listItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Text('•',
                            style: TextStyle(
                                color: tokens.primary,
                                fontWeight: FontWeight.w900)),
                      ),
                      Expanded(child: _RichText(text: item, tokens: tokens)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case _BlockType.orderedList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var idx = 0; idx < b.listItems.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Text(
                          '${idx + 1}.',
                          style: TextStyle(
                            color: tokens.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                          child: _RichText(
                              text: b.listItems[idx], tokens: tokens)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case _BlockType.taskList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in b.tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Icon(
                          t.done ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: t.done ? tokens.primary : tokens.muted,
                        ),
                      ),
                      Expanded(
                        child: _RichText(
                          text: t.text,
                          tokens: tokens,
                          strikethrough: t.done,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
    }
  }

  double _headingSize(int level) {
    switch (level) {
      case 1:
        return 22;
      case 2:
        return 19;
      case 3:
        return 17;
      case 4:
        return 15;
      default:
        return 14;
    }
  }
}

/// 行内富文本：解析 `**粗体**`、`` `代码` ``、`*斜体*`。
class _RichText extends StatelessWidget {
  const _RichText({required this.text, required this.tokens, this.strikethrough = false});

  final String text;
  final Phase1ToneTokens tokens;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final spans = _parseInline(text);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: strikethrough ? tokens.muted : tokens.text,
          fontSize: 15,
          height: 1.55,
          decoration:
              strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parseInline(String s) {
    final spans = <InlineSpan>[];
    // 顺序：code > bold > italic。
    final re = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) {
        spans.add(TextSpan(text: s.substring(last, m.start)));
      }
      final seg = m.group(0)!;
      if (seg.startsWith('`')) {
        spans.add(TextSpan(
          text: seg.substring(1, seg.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: tokens.muted.withValues(alpha: 0.16),
            color: tokens.primary,
          ),
        ));
      } else if (seg.startsWith('**')) {
        spans.add(TextSpan(
          text: seg.substring(2, seg.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ));
      } else {
        spans.add(TextSpan(
          text: seg.substring(1, seg.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }
    if (last < s.length) {
      spans.add(TextSpan(text: s.substring(last)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: s));
    return spans;
  }
}

enum _BlockType {
  heading,
  paragraph,
  image,
  quote,
  code,
  divider,
  unorderedList,
  orderedList,
  taskList,
}

class _Block {
  const _Block(
    this.type,
    this.content, {
    this.level = 0,
    this.lang = '',
    this.listItems = const [],
    this.tasks = const [],
    this.imageHash = '',
    this.imageExt = '',
    this.imageAlt = '',
  });

  final _BlockType type;
  final String content;
  final int level;
  final String lang;
  final List<String> listItems;
  final List<_TaskItem> tasks;
  // 图片块专用。
  final String imageHash;
  final String imageExt;
  final String imageAlt;
}

class _TaskItem {
  const _TaskItem({required this.done, required this.text});
  final bool done;
  final String text;
}

/// 图片语法解析中间结果（hash/ext/alt）。
class _ImageRef {
  const _ImageRef({required this.hash, required this.ext, required this.alt});
  final String hash;
  final String ext;
  final String alt;
}

/// 附件图片渲染（阶段八核心）：本地缓存优先 → 缺失懒拉取 → 三态（加载中/实图/缺图重试）。
///
/// 关键约束：**缺图不阻塞**。整个 MarkdownView 同步渲染完成后，图片独立异步加载，
/// 失败时显示「点击重试」占位，联网后用户可重试。
class _AttachmentImage extends StatefulWidget {
  const _AttachmentImage({
    required this.hash,
    required this.ext,
    required this.alt,
    required this.tokens,
    this.service,
  });

  final String hash;
  final String ext;
  final String alt;
  final Phase1ToneTokens tokens;
  final AttachmentService? service;

  @override
  State<_AttachmentImage> createState() => _AttachmentImageState();
}

/// 渲染状态：loading（加载中/懒拉取）/ loaded（已显示实图）/ missing（缺图，可重试）。
enum _ImageLoadState { loading, loaded, missing }

class _AttachmentImageState extends State<_AttachmentImage> {
  _ImageLoadState _state = _ImageLoadState.loading;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    // 首帧后异步加载，避免阻塞 Markdown 主体渲染。
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final service = widget.service;
    if (service == null) {
      // 无服务（如无 ref 的纯预览）→ 缺图占位。
      if (mounted) setState(() => _state = _ImageLoadState.missing);
      return;
    }
    setState(() => _state = _ImageLoadState.loading);
    final bytes = await service.ensure(widget.hash, widget.ext);
    if (!mounted) return;
    if (bytes != null) {
      setState(() {
        _bytes = bytes;
        _state = _ImageLoadState.loaded;
      });
    } else {
      setState(() => _state = _ImageLoadState.missing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    switch (_state) {
      case _ImageLoadState.loading:
        return _placeholder(
          child: SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
                ),
              ),
            ),
          ),
        );
      case _ImageLoadState.loaded:
        final bytes = _bytes;
        if (bytes == null) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => _placeholder(
              icon: Icons.broken_image_outlined,
              label: widget.alt.isEmpty ? '图片无法显示' : widget.alt,
            ),
          ),
        );
      case _ImageLoadState.missing:
        return GestureDetector(
          onTap: _load,
          child: _placeholder(
            icon: Icons.image_not_supported_outlined,
            label: widget.alt.isEmpty ? '图片未下载，点击重试' : '${widget.alt}（点击重试）',
            tappable: true,
          ),
        );
    }
  }

  Widget _placeholder({
    Widget? child,
    IconData icon = Icons.image_outlined,
    String label = '',
    bool tappable = false,
  }) {
    final t = widget.tokens;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.muted.withValues(alpha: 0.2)),
      ),
      child: child ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: t.muted),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted, fontSize: 12),
              ),
            ],
          ),
    );
  }
}
