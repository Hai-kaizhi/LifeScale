import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/core/storage/app_paths.dart';
import 'package:lifescale_mobile/core/storage/database_service.dart';
import 'package:lifescale_mobile/core/storage/prefs_store.dart';
import 'package:lifescale_mobile/features/notes/data/notes_repository.dart';
import 'package:lifescale_mobile/features/vault/data/vault_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/temp_dir_helper.dart';

/// 笔记仓库测试（开源本地版）：列表过滤（排除 Daily/scheme/conflict）+ 新建 + 读取 + 保存。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService().close();
    SharedPreferences.setMockInitialValues({});
  });

  test('listNotes 过滤掉 Daily / Reviews/scheme.md / conflict 副本', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    // 预置几个 Vault 文件（通过 createNote + 直接推送）。
    await h.repo.createNote('产品笔记');
    await h.repo.saveNote('Notes/移动端 Phase 1 同步说明.md', '# 已有笔记\n\n正文。');
    // 不应出现在列表的：
    // - Daily/2026-06-18.md（mock 种子，Daily 子目录）
    // 拉取列表。
    final notes = await h.repo.listNotes();
    // 应仅包含 .md 且非 Daily/scheme/conflict。
    for (final n in notes) {
      expect(n.vaultPath.startsWith('Daily/'), isFalse);
      expect(n.vaultPath == 'Reviews/scheme.md', isFalse);
      expect(n.vaultPath.contains('.conflict-'), isFalse);
    }
    // 新建的「产品笔记」应在列表中。
    expect(
      notes.any((n) => n.vaultPath == 'Notes/产品笔记.md'),
      isTrue,
    );
  });

  test('createNote 落地 Notes/ 下 .md 且内容为标题 + 空行', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    final path = await h.repo.createNote('会议纪要');
    expect(path, 'Notes/会议纪要.md');
    final content = await File('${AppPaths.appDocs}/$path').readAsString();
    expect(content, contains('# 会议纪要'));
  });

  test('readNote 本地优先，保存后可读回', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    const md = '# 测试笔记\n\n- 一\n- 二';
    await h.repo.saveNote('Notes/测试笔记.md', md);
    final read = await h.repo.readNote('Notes/测试笔记.md');
    expect(read, md);
  });

  test('createNote 命名冲突自动加序号', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    final p1 = await h.repo.createNote('同名笔记');
    final p2 = await h.repo.createNote('同名笔记');
    expect(p1, 'Notes/同名笔记.md');
    expect(p2, 'Notes/同名笔记-1.md');
  });
}

class _Harness {
  const _Harness({required this.temp, required this.repo});

  final Directory temp;
  final NotesRepository repo;

  static Future<_Harness> create() async {
    final temp = await Directory.systemTemp.createTemp('lifescale_notes_');
    await AppPaths.initForTest(temp.path);
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PrefsStore(sharedPrefs);
    final vaultRepo = VaultRepository(DatabaseService(), prefs);
    return _Harness(temp: temp, repo: NotesRepository(vaultRepo));
  }

  Future<void> dispose() async {
    await DatabaseService().close();
    await safeDeleteTempDir(temp);
  }
}
