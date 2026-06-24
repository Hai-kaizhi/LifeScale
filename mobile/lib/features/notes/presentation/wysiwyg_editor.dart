import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../attachments/data/attachment_service.dart';
import '../../attachments/domain/attachment_ref.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';

/// WYSIWYG Markdown 编辑器（Typora 风格）：默认渲染态可编辑，输入 `# `/`**` 等自动渲染。
///
/// 对外契约是**整篇 Markdown 字符串**：
/// - 入参 [markdown] 经 `markdownToDocument` 解析为 appflowy_editor 的 Document。
/// - 内部编辑经 `documentToMarkdown` 序列化后通过 [onChanged] 吐出。
/// 这样 [NotesRepository.saveNote] 的整文 push / 乐观锁链路零改动，与桌面端互通。
///
/// **附件图片关键设计**：appflowy 默认的 `ResizableImage` 把非 URL/非 base64 的 src 当
/// 本地文件绝对路径加载（`Image.file(File(src))`）。我们的 `attachments/<hash>.<ext>` 是
/// 相对引用，会被误判为文件路径 → `PathNotFoundException`。因此本编辑器**自定义 image block
/// 组件**，识别 `attachments/` 前缀 → 解析 hash/ext → 经 [AttachmentService.ensure] 懒拉取
/// → `Image.memory` 显示；非内容寻址的 URL 降级到默认加载行为。
class WysiwygEditor extends StatefulWidget {
  const WysiwygEditor({
    super.key,
    required this.markdown,
    this.attachmentService,
    this.tokens,
    required this.onChanged,
  });

  /// 初始整篇 Markdown。
  final String markdown;

  /// 附件懒拉取服务（识别 attachments/ 引用必需；为空时图片显示占位）。
  final AttachmentService? attachmentService;

  /// 色调 token（文字色/光标色跟随全局时段）。
  final Phase1ToneTokens? tokens;

  /// 内容变化回调，吐序列化后的整篇 Markdown。
  final ValueChanged<String> onChanged;

  @override
  State<WysiwygEditor> createState() => WysiwygEditorState();
}

class WysiwygEditorState extends State<WysiwygEditor> {
  late EditorState _editorState;
  StreamSubscription? _sub;
  Timer? _debounce;
  String _lastEmitted = '';
  bool _suppressEmit = false;

  @override
  void initState() {
    super.initState();
    _editorState = _buildEditorState(widget.markdown);
    _lastEmitted = widget.markdown;
    _sub = _editorState.transactionStream.listen(_onTransaction);
  }

  @override
  void didUpdateWidget(covariant WysiwygEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部 markdown 变化（如切回此模式、云端覆盖）且与当前不一致时重建文档。
    if (widget.markdown != oldWidget.markdown &&
        widget.markdown != _lastEmitted) {
      _rebuildDocument(widget.markdown);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  /// 供 page 层取当前最新内容（切换模式时用）。
  String get currentMarkdown {
    try {
      final md = documentToMarkdown(_editorState.document);
      // 完整性兜底：序列化异常为空但文档非空时，保留上次有效值（规避 Issue #1134）。
      if (md.isEmpty && _editorState.document.root.children.isNotEmpty) {
        return _lastEmitted;
      }
      return md;
    } catch (_) {
      return _lastEmitted;
    }
  }

  /// 在当前光标位置插入一张图片（内容寻址相对引用）。
  /// 供 page 层 `_pickAndInsertImage` 在 WYSIWYG 模式下调用。
  Future<void> insertImageMarkdown(String relPath) async {
    final node = imageNode(url: relPath);
    final selection = _editorState.selection;
    Path insertPath;
    if (selection != null) {
      final cur = selection.start.path;
      insertPath = [cur[0] + 1, ...cur.sublist(1)];
    } else {
      final last = _editorState.document.root.children.lastOrNull;
      insertPath = last == null ? [0] : [last.path[0] + 1];
    }
    final transaction = _editorState.transaction;
    transaction.insertNode(insertPath, node);
    await _editorState.apply(transaction);
  }

  EditorState _buildEditorState(String markdown) {
    final md = markdown.trim().isEmpty ? '' : markdown;
    Document doc;
    try {
      doc = markdownToDocument(md);
    } catch (_) {
      doc = Document(root: paragraphNode(delta: Delta()..insert(md)));
    }
    return EditorState(document: doc);
  }

  void _rebuildDocument(String markdown) {
    _suppressEmit = true;
    _sub?.cancel();
    _editorState = _buildEditorState(markdown);
    _lastEmitted = markdown;
    _sub = _editorState.transactionStream.listen(_onTransaction);
    _suppressEmit = false;
    setState(() {});
  }

  void _onTransaction(_) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _suppressEmit) return;
      final md = currentMarkdown;
      if (md != _lastEmitted) {
        _lastEmitted = md;
        widget.onChanged(md);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final style = tokens == null
        ? const EditorStyle.mobile(padding: EdgeInsets.all(16))
        : EditorStyle.mobile(
            padding: const EdgeInsets.all(16),
            cursorColor: tokens.primary,
            selectionColor: tokens.primary.withValues(alpha: 0.2),
            textStyleConfiguration: TextStyleConfiguration(
              text: TextStyle(color: tokens.text, fontSize: 15, height: 1.6),
            ),
          );

    // 覆盖默认 image builder：内容寻址附件走自定义懒拉取组件。
    final builders = Map<String, BlockComponentBuilder>.from(
      standardBlockComponentBuilderMap,
    );
    builders[ImageBlockKeys.type] = _AttachmentImageBlockBuilder(
      attachmentService: widget.attachmentService,
      tokens: tokens,
    );

    return AppFlowyEditor(
      editorState: _editorState,
      editable: true,
      autoFocus: true,
      editorStyle: style,
      blockComponentBuilders: builders,
    );
  }
}

// ============================ 自定义附件图片 block ============================

/// 自定义 image block builder：用 [_AttachmentImageBlockWidget] 替换默认 ResizableImage，
/// 识别 `attachments/<hash>.<ext>` 内容寻址引用并懒拉取，避免 PathNotFoundException。
class _AttachmentImageBlockBuilder extends BlockComponentBuilder {
  _AttachmentImageBlockBuilder({
    this.attachmentService,
    this.tokens,
  }) : super();

  final AttachmentService? attachmentService;
  final Phase1ToneTokens? tokens;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return _AttachmentImageBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: const BlockComponentConfiguration(),
      attachmentService: attachmentService,
      tokens: tokens,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class _AttachmentImageBlockWidget extends BlockComponentStatefulWidget {
  const _AttachmentImageBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
    this.attachmentService,
    this.tokens,
  });

  final AttachmentService? attachmentService;
  final Phase1ToneTokens? tokens;

  @override
  State<_AttachmentImageBlockWidget> createState() =>
      _AttachmentImageBlockWidgetState();
}

class _AttachmentImageBlockWidgetState
    extends State<_AttachmentImageBlockWidget> {
  @override
  Widget build(BuildContext context) {
    final src = widget.node.attributes[ImageBlockKeys.url]?.toString() ?? '';
    final tokens = widget.tokens ?? Phase1Theme.of(TodayTone.values.first);

    // 内容寻址附件引用 → 自定义懒拉取组件。
    final m = attachmentRefRegex.firstMatch(src);
    if (m != null) {
      return _AttachmentInlineImage(
        hash: m.group(1)!,
        ext: m.group(2)!,
        service: widget.attachmentService,
        tokens: tokens,
      );
    }
    // 其它 URL（网络图）/ 绝对路径 → 显示占位（移动端不支持外部路径图片），
    // 避免直接 Image.file 触发 PathNotFoundException 红屏。
    return _UnavailableImage(
      reason: '不支持的外部图片：$src',
      tokens: tokens,
    );
  }
}

/// 内联附件图片（复用阶段八三态逻辑：加载中/实图/缺图重试）。
class _AttachmentInlineImage extends StatefulWidget {
  const _AttachmentInlineImage({
    required this.hash,
    required this.ext,
    required this.service,
    required this.tokens,
  });

  final String hash;
  final String ext;
  final AttachmentService? service;
  final Phase1ToneTokens tokens;

  @override
  State<_AttachmentInlineImage> createState() => _AttachmentInlineImageState();
}

enum _ImgState { loading, loaded, missing }

class _AttachmentInlineImageState extends State<_AttachmentInlineImage> {
  _ImgState _state = _ImgState.loading;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final service = widget.service;
    if (service == null) {
      if (mounted) setState(() => _state = _ImgState.missing);
      return;
    }
    setState(() => _state = _ImgState.loading);
    final bytes = await service.ensure(widget.hash, widget.ext);
    if (!mounted) return;
    if (bytes != null) {
      setState(() {
        _bytes = bytes;
        _state = _ImgState.loaded;
      });
    } else {
      setState(() => _state = _ImgState.missing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    switch (_state) {
      case _ImgState.loading:
        return _box(
          t,
          child: const SizedBox(
            width: double.infinity,
            height: 120,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      case _ImgState.loaded:
        final bytes = _bytes;
        if (bytes == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _box(t,
                  child: const Center(child: Icon(Icons.broken_image, size: 32))),
            ),
          ),
        );
      case _ImgState.missing:
        return GestureDetector(
          onTap: _load,
          child: _box(
            t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 28, color: t.muted),
                const SizedBox(height: 6),
                Text('图片未下载，点击重试',
                    style: TextStyle(color: t.muted, fontSize: 12)),
              ],
            ),
          ),
        );
    }
  }

  Widget _box(Phase1ToneTokens t, {required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.muted.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

/// 不支持的外部图片占位（避免红屏 PathNotFoundException）。
class _UnavailableImage extends StatelessWidget {
  const _UnavailableImage({required this.reason, required this.tokens});
  final String reason;
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.muted.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 26, color: tokens.muted),
          const SizedBox(height: 6),
          Text(reason,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted, fontSize: 11)),
        ],
      ),
    );
  }
}
