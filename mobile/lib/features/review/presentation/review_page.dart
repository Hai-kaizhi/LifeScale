import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import '../domain/review_models.dart';
import 'review_controller.dart';

/// 复盘页：读取方案题目 + 当天答案，逐题填写，保存写回当天 Daily 的 ## 今日复盘 段，
/// 并可「沉淀」生成 Vault 文档。
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, this.date});

  final String? date;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  @override
  void initState() {
    super.initState();
    if (widget.date != null && widget.date!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reviewControllerProvider.notifier).setDate(widget.date!);
        ref.read(reviewControllerProvider.notifier).loadReview();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider);
    final controller = ref.read(reviewControllerProvider.notifier);
    // 时段色调跟随全局 ThemeController（不再写死 night）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);

    ref.listen<ReviewState>(reviewControllerProvider, (_, next) {
      final message = next.message;
      if (message == null || message.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 顶部栏
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: tokens.text,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日复盘',
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          state.data?.scheme.name ?? '官方默认方案',
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 沉淀按钮。结果 message 由顶部 ref.listen 统一展示为 SnackBar。
                  TextButton.icon(
                    onPressed: state.saving
                        ? null
                        : () => controller.precipitate(),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: const Text('沉淀'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(state, controller, tokens)),
        ],
      ),
    );
  }

  Widget _body(
    ReviewState state,
    ReviewController controller,
    Phase1ToneTokens tokens,
  ) {
    switch (state.status) {
      case ReviewLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ReviewLoadStatus.error:
        return _CenterMessage(
          tokens: tokens,
          icon: Icons.error_outline,
          text: state.message ?? '复盘加载失败',
          action: '重试',
          onAction: controller.loadReview,
        );
      case ReviewLoadStatus.ready:
      case ReviewLoadStatus.empty:
        final data = state.data;
        if (data == null) {
          return _CenterMessage(
            tokens: tokens,
            icon: Icons.nightlight_round,
            text: '暂无复盘内容',
          );
        }
        return _ReviewForm(
          state: state,
          data: data,
          tokens: tokens,
          onAnswerChanged: controller.updateAnswer,
          onSave: controller.save,
        );
    }
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.state,
    required this.data,
    required this.tokens,
    required this.onAnswerChanged,
    required this.onSave,
  });

  final ReviewState state;
  final ReviewViewData data;
  final Phase1ToneTokens tokens;
  final void Function(String questionId, String text) onAnswerChanged;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            itemCount: data.items.length,
            itemBuilder: (context, index) {
              final item = data.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassPanel(
                  tone: tokens.tone,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.nightlight_round,
                                color: tokens.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.question.title,
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.question.required)
                              Text(
                                '必填',
                                style: TextStyle(
                                  color: tokens.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // initialValue 仅首次生效；rebuild 不会重置，符合「编辑内存态」需求。
                        TextFormField(
                          initialValue: item.answer,
                          enabled: data.canEdit,
                          maxLines: 5,
                          minLines: 3,
                          maxLength: item.question.maxLength,
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: item.question.placeholder ??
                                '写下你的复盘…',
                            hintStyle: TextStyle(color: tokens.muted),
                            filled: true,
                            fillColor: tokens.muted.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: tokens.muted.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: tokens.muted.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: tokens.primary, width: 1.5),
                            ),
                          ),
                          onChanged: (text) =>
                              onAnswerChanged(item.question.id, text),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 底部保存栏（仅今天可保存）。
        if (data.canEdit)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: FilledButton.icon(
                onPressed: state.saving ? null : () => onSave(),
                icon: state.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存复盘'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: tokens.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Text(
                '历史复盘只读，仅今天可填写',
                style: TextStyle(color: tokens.muted, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tokens.muted, size: 48),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: tokens.muted, fontSize: 15),
            textAlign: TextAlign.center,
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
    );
  }
}
