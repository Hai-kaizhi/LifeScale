import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notes_repository.dart';
import '../domain/notes_models.dart';

/// 笔记列表控制器：加载列表、搜索过滤、新建。
class NotesController extends Notifier<NotesState> {
  @override
  NotesState build() {
    Future<void>.microtask(loadNotes);
    return const NotesState();
  }

  Future<void> loadNotes() async {
    state = state.copyWith(status: NotesLoadStatus.loading, clearMessage: true);
    try {
      final notes = await ref.read(notesRepositoryProvider).listNotes();
      state = state.copyWith(
        status: notes.isEmpty ? NotesLoadStatus.empty : NotesLoadStatus.ready,
        notes: notes,
      );
    } catch (e) {
      state = state.copyWith(
        status: NotesLoadStatus.error,
        message: '笔记列表加载失败：$e',
      );
    }
  }

  void setFilter(String text) {
    state = state.copyWith(filter: text, clearFilter: text.isEmpty);
  }

  /// 新建笔记，返回新建的 vault 路径（失败返回 null）。
  Future<String?> createNote(String title) async {
    try {
      final path = await ref.read(notesRepositoryProvider).createNote(title);
      await loadNotes();
      return path;
    } catch (e) {
      state = state.copyWith(message: '新建失败：$e');
      return null;
    }
  }
}

final notesControllerProvider =
    NotifierProvider<NotesController, NotesState>(NotesController.new);

/// 笔记编辑状态。
/// - [wysiwyg]：所见即所得（appflowy_editor 渲染态可编辑，Typora 风格，默认）。
/// - [source]：Markdown 源码（等宽纯文本）。
enum EditorMode { wysiwyg, source }
enum EditorLoadStatus { loading, ready, notFound, error }

class NoteEditorState {
  const NoteEditorState({
    this.vaultPath = '',
    this.status = EditorLoadStatus.loading,
    this.content = '',
    this.mode = EditorMode.wysiwyg,
    this.saving = false,
    this.message,
    this.dirty = false,
  });

  final String vaultPath;
  final EditorLoadStatus status;
  final String content;
  final EditorMode mode;
  final bool saving;
  final String? message;
  final bool dirty; // 本地有未推送修改

  NoteEditorState copyWith({
    String? vaultPath,
    EditorLoadStatus? status,
    String? content,
    EditorMode? mode,
    bool? saving,
    String? message,
    bool clearMessage = false,
    bool? dirty,
  }) =>
      NoteEditorState(
        vaultPath: vaultPath ?? this.vaultPath,
        status: status ?? this.status,
        content: content ?? this.content,
        mode: mode ?? this.mode,
        saving: saving ?? this.saving,
        message: clearMessage ? null : message ?? this.message,
        dirty: dirty ?? this.dirty,
      );
}

/// 单篇笔记编辑器控制器（普通 Notifier；打开不同笔记前调用 open(path)）。
class NoteEditorController extends Notifier<NoteEditorState> {
  @override
  NoteEditorState build() => const NoteEditorState();

  /// 打开指定笔记（路由进入时调用）。同 path 不重复加载。
  Future<void> open(String vaultPath) async {
    if (vaultPath.isEmpty) {
      state = NoteEditorState(
        vaultPath: '',
        status: EditorLoadStatus.notFound,
        message: '笔记路径为空',
      );
      return;
    }
    if (state.vaultPath == vaultPath && state.status == EditorLoadStatus.ready) {
      return; // 已加载同一篇
    }
    state = NoteEditorState(vaultPath: vaultPath);
    await _load(vaultPath);
  }

  Future<void> _load(String vaultPath) async {
    state = state.copyWith(
        vaultPath: vaultPath,
        status: EditorLoadStatus.loading,
        clearMessage: true);
    final content =
        await ref.read(notesRepositoryProvider).readNote(vaultPath);
    if (content == null) {
      state = state.copyWith(
        status: EditorLoadStatus.notFound,
        message: '笔记不存在或加载失败',
      );
      return;
    }
    state = state.copyWith(
      status: EditorLoadStatus.ready,
      content: content,
      clearMessage: true,
    );
  }

  void setMode(EditorMode mode) =>
      state = state.copyWith(mode: mode, clearMessage: true);

  /// 切换编辑模式前同步内容：把当前模式的最新 Markdown 写回 state.content，
  /// 避免 wysiwyg ↔ source 切换时丢失未保存改动。同时标 dirty 触发防抖保存。
  void syncContentAndSwitch(String markdown, EditorMode nextMode) {
    state = state.copyWith(
      content: markdown,
      dirty: markdown != state.content ? true : state.dirty,
      mode: nextMode,
      clearMessage: true,
    );
  }

  void onContentChanged(String text) =>
      state = state.copyWith(content: text, dirty: true, clearMessage: true);

  Future<bool> save() async {
    if (state.vaultPath.isEmpty) return false;
    state = state.copyWith(saving: true, clearMessage: true);
    try {
      final msg = await ref
          .read(notesRepositoryProvider)
          .saveNote(state.vaultPath, state.content);
      state = state.copyWith(
        saving: false,
        dirty: false,
        message: msg,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        saving: false,
        message: '保存失败：$e',
      );
      return false;
    }
  }
}

final noteEditorControllerProvider =
    NotifierProvider<NoteEditorController, NoteEditorState>(
        NoteEditorController.new);
