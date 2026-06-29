import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_providers.dart';
import '../../attachments/domain/attachment_ref.dart';
import '../../vault/vault_providers.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import 'notes_controller.dart';
import 'wysiwyg_editor.dart';

/// 笔记编辑器：预览（Markdown 渲染）↔ 编辑（纯文本）切换，防抖保存。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, required this.path});

  final String path;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  TextEditingController? _controller;
  Timer? _debounce;
  String _hydratedFor = '';
  // WYSIWYG 编辑器的 key：切换模式时取当前序列化的 Markdown，避免丢内容。
  final GlobalKey<WysiwygEditorState> _wysiwygKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 进入页面即加载该笔记（普通 Notifier，按 path 打开）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(noteEditorControllerProvider.notifier).open(widget.path);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// 首次拿到内容时（或内容来源变化时）灌入 controller。幂等。
  /// 仅在 MD 源码模式需要；WYSIWYG 模式由 appflowy_editor 自管文档。
  /// 注意：切换模式时 state.content 会更新，本方法据此自动重建 controller，
  /// 不在别处手动 dispose，避免「used after disposed」。
  void _ensureController(NoteEditorState state) {
    if (state.status != EditorLoadStatus.ready) return;
    if (state.mode != EditorMode.source) return;
    // 进入 source 模式或内容变化时，按需（重新）创建 controller。
    if (_controller == null) {
      _controller = TextEditingController(text: state.content);
      _hydratedFor = state.content;
    } else if (_hydratedFor != state.content) {
      // 用 value 更新而非重建，避免 dispose 后旧 widget 仍在引用。
      _controller!.value = TextEditingValue(
        text: state.content,
        selection: const TextSelection.collapsed(offset: -1),
      );
      _hydratedFor = state.content;
    }
  }

  void _onChanged(String text) {
    ref
        .read(noteEditorControllerProvider.notifier)
        .onContentChanged(text);
    // 防抖保存：停止输入 1.2s 后自动推送。
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      ref.read(noteEditorControllerProvider.notifier).save();
    });
  }

  /// 切换 wysiwyg ↔ source：先把当前模式的最新 Markdown 同步进 state，再切 mode。
  /// 不在此处手动 dispose/create controller，交由 _ensureController 按 content 变化幂等管理，
  /// 避免切换时序导致的「TextEditingController used after being disposed」。
  void _switchMode(NoteEditorController notifier) {
    final current = ref.read(noteEditorControllerProvider);
    final latestMarkdown = current.mode == EditorMode.wysiwyg
        ? (_wysiwygKey.currentState?.currentMarkdown ?? current.content)
        : (_controller?.text ?? current.content);
    final next = current.mode == EditorMode.wysiwyg
        ? EditorMode.source
        : EditorMode.wysiwyg;
    notifier.syncContentAndSwitch(latestMarkdown, next);
    // syncContentAndSwitch 已更新 state.content，_ensureController 会在下次 build
    // 时据此创建/更新 controller，无需此处干预。
  }

  /// 选择图片 → 上传 → 在光标处插入 Markdown 图片引用（阶段八轻量上传）。
  /// 失败时提示，不阻断编辑。两种模式分别处理：
  /// - WYSIWYG：调编辑器 `insertImageMarkdown` 插入 image 节点。
  /// - source：向 TextEditingController 光标处插文本。
  bool _insertingImage = false;
  Future<void> _pickAndInsertImage() async {
    if (_insertingImage) return;
    final mode = ref.read(noteEditorControllerProvider).mode;
    setState(() => _insertingImage = true);
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return; // 用户取消
      final bytes = await xFile.readAsBytes();
      final ext = extFromMime(xFile.mimeType ?? 'image/png');
      final service = ref.read(attachmentServiceProvider);
      final ref0 = await service.upload(bytes, ext);
      if (mode == EditorMode.wysiwyg) {
        // WYSIWYG：插入 image 节点。
        await _wysiwygKey.currentState?.insertImageMarkdown(ref0.relPath);
        return;
      }
      // source：向 TextField 光标处插文本。
      final ctrl = _controller;
      if (ctrl == null) return;
      final markdown = '![图片](${ref0.relPath})';
      final value = ctrl.value;
      final sel = value.selection;
      final newText = sel.isValid
          ? value.text.replaceRange(sel.start, sel.end, markdown)
          : '${value.text}$markdown';
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (sel.isValid ? sel.start : value.text.length) + markdown.length,
        ),
      );
      _onChanged(newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text('图片插入失败：$e'),
              duration: const Duration(seconds: 2)));
      }
    } finally {
      if (mounted) setState(() => _insertingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteEditorControllerProvider);
    final notifier =
        ref.read(noteEditorControllerProvider.notifier);
    // 时段色调跟随全局 ThemeController（不再写死 night）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);

    _ensureController(state);

    ref.listen(noteEditorControllerProvider, (_, next) {
      final msg = next.message;
      if (msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    });

    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 顶部栏：返回 + 标题 + 预览/编辑切换
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: tokens.text,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _titleOfPath(widget.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  // 待同步徽标
                  if (state.dirty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '待同步',
                        style: TextStyle(
                          color: tokens.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (state.saving)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  TextButton(
                    onPressed: state.status == EditorLoadStatus.ready
                        ? () => _switchMode(notifier)
                        : null,
                    child: Text(
                      state.mode == EditorMode.wysiwyg ? 'MD源码' : '预览编辑',
                      style: TextStyle(
                        color: tokens.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(state, notifier, tokens)),
        ],
      ),
    );
  }

  Widget _body(
      NoteEditorState state, NoteEditorController notifier, Phase1ToneTokens tokens) {
    switch (state.status) {
      case EditorLoadStatus.loading:
        return Center(child: CircularProgressIndicator(color: tokens.primary));
      case EditorLoadStatus.notFound:
      case EditorLoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              state.message ?? '笔记加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.muted, fontSize: 15),
            ),
          ),
        );
      case EditorLoadStatus.ready:
        if (state.mode == EditorMode.source) {
          // MD 源码模式：等宽纯文本，输入即防抖保存。
          final ctrl = _controller;
          if (ctrl == null) {
            return Center(
                child: CircularProgressIndicator(color: tokens.primary));
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              children: [
                // 轻量工具栏：仅图片插入（符合「轻编辑」定位）。
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ImageInsertButton(
                    tokens: tokens,
                    inserting: _insertingImage,
                    onTap: _pickAndInsertImage,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 15,
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '输入 Markdown…',
                      hintStyle: TextStyle(color: tokens.muted),
                      filled: true,
                      fillColor: tokens.muted.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ],
            ),
          );
        }
        // 默认 WYSIWYG 模式：所见即所得（appflowy_editor 渲染态可编辑）。
        // 空内容时仍渲染编辑器（用户可直接输入，体验优于占位文案）。
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _ImageInsertButton(
                  tokens: tokens,
                  inserting: _insertingImage,
                  onTap: _pickAndInsertImage,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GlassPanel(
                  tone: tokens.tone,
                  child: WysiwygEditor(
                    key: _wysiwygKey,
                    markdown: state.content,
                    attachmentService:
                        ref.read(attachmentServiceProvider),
                    tokens: tokens,
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  String _titleOfPath(String path) {
    final name = path.split('/').last;
    return name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }
}

/// 编辑器工具栏：图片插入按钮（上传中显示菊花）。
class _ImageInsertButton extends StatelessWidget {
  const _ImageInsertButton({
    required this.tokens,
    required this.inserting,
    required this.onTap,
  });

  final Phase1ToneTokens tokens;
  final bool inserting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: inserting ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inserting)
              SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: tokens.primary),
              )
            else
              Icon(Icons.image_outlined, size: 16, color: tokens.primary),
            const SizedBox(width: 6),
            Text(
              inserting ? '上传中…' : '图片',
              style: TextStyle(
                color: tokens.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
