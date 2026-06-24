import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/theme/theme_providers.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import '../domain/notes_models.dart';
import 'notes_controller.dart';

/// 笔记列表页：搜索 + 最近笔记卡片 + 新建。
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);
    // 时段色调跟随全局 ThemeController（不再写死 night）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);

    ref.listen<NotesState>(notesControllerProvider, (_, next) {
      final msg = next.message;
      if (msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });

    // 监听 AppShell 中央「+」创建信号：值变化时打开新建对话框。
    ref.listen<int>(
      notesCreateSignalProvider.select((n) => n.value),
      (_, value) {
        if (value == 0) return;
        _showCreateDialog(context, controller, tokens);
      },
    );

    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 顶部栏
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      color: tokens.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '笔记',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    color: tokens.text,
                    onPressed: controller.loadNotes,
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined),
                    color: tokens.primary,
                    tooltip: '新建笔记',
                    onPressed: () =>
                        _showCreateDialog(context, controller, tokens),
                  ),
                ],
              ),
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: TextField(
              onChanged: controller.setFilter,
              decoration: InputDecoration(
                hintText: '搜索笔记标题或路径',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: tokens.muted.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
          Expanded(child: _body(state, controller, tokens, context)),
        ],
      ),
    );
  }

  Widget _body(
    NotesState state,
    NotesController controller,
    Phase1ToneTokens tokens,
    BuildContext context,
  ) {
    switch (state.status) {
      case NotesLoadStatus.loading:
        return Center(child: CircularProgressIndicator(color: tokens.primary));
      case NotesLoadStatus.error:
        return _Msg(
          tokens: tokens,
          icon: Icons.error_outline,
          text: state.message ?? '加载失败',
          action: '重试',
          onAction: controller.loadNotes,
        );
      case NotesLoadStatus.empty:
        return _Msg(
          tokens: tokens,
          icon: Icons.note_add_outlined,
          text: '还没有笔记，点击下方「新建笔记」开始记录',
        );
      case NotesLoadStatus.ready:
        final list = state.filtered;
        if (list.isEmpty) {
          return _Msg(
            tokens: tokens,
            icon: Icons.search_off,
            text: '没有匹配的笔记',
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadNotes,
          color: tokens.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final note = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NoteCard(
                  note: note,
                  tokens: tokens,
                  onTap: () => context.push('/notes/editor?path=${Uri.encodeComponent(note.vaultPath)}'),
                ),
              );
            },
          ),
        );
    }
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    NotesController controller,
    Phase1ToneTokens tokens,
  ) async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建笔记'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入笔记标题',
            labelText: '标题',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final path = await controller.createNote(title);
    if (path != null && context.mounted) {
      context.push('/notes/editor?path=${Uri.encodeComponent(path)}');
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.tokens,
    required this.onTap,
  });

  final NoteSummary note;
  final Phase1ToneTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tokens.tone,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: tokens.primary.withValues(alpha: 0.12),
          child: Icon(Icons.description_outlined, color: tokens.primary),
        ),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              note.vaultPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (!note.synced)
                  _badge('待同步', tokens.warning, tokens)
                else
                  _badge('已同步', tokens.success, tokens),
                const SizedBox(width: 8),
                if (note.relativeTime.isNotEmpty)
                  Text(
                    note.relativeTime,
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: tokens.muted),
      ),
    );
  }

  Widget _badge(String text, Color color, Phase1ToneTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  const _Msg({
    required this.tokens,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final Phase1ToneTokens tokens;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.muted, fontSize: 15),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
