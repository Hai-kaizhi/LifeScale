import 'package:dio/dio.dart';

import 'mock_api_data.dart';

/// Mock API 拦截器：模拟后端 `/api/auth/*`、`/api/vault/*`。
///
/// 数据源为 **Daily Markdown / Vault Markdown**（单一事实来源）：今日重点/日程/快速
/// 记录/复盘、复盘方案、沉淀文档全部通过 `/api/vault/files` 读写。不再模拟 Model B
/// 旧 REST（schedules/quick-notes/date-entity/daily-reviews）。
class MockApiInterceptor extends Interceptor {
  MockApiInterceptor({this.scenario = 'normal'});

  final String scenario;
  final List<Map<String, dynamic>> _registeredDevices = [];
  Map<String, MockVaultFile>? _files;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    if (scenario == 'offline') {
      return handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'mock offline',
        ),
      );
    }

    if (path == '/auth/login' && options.method == 'POST') {
      return _reply(handler, options, _login(options.data));
    }
    if (path == '/auth/me' && options.method == 'GET') {
      return _reply(handler, options, _ok(_currentUser()));
    }
    if (path == '/auth/devices' && options.method == 'POST') {
      return _reply(handler, options, _registerDevice(options.data));
    }
    if (path == '/auth/devices' && options.method == 'GET') {
      return _reply(handler, options, _ok(_registeredDevices));
    }
    if (path == '/vault/changes' && options.method == 'GET') {
      return _reply(handler, options, _changes());
    }
    if (path == '/vault/files' && options.method == 'GET') {
      return _reply(handler, options, _file(options.queryParameters['path']));
    }
    if (path == '/vault/files' && options.method == 'PUT') {
      return _reply(handler, options, _pushFile(options.data));
    }
    // 当天实体同步（docs/09 §9.3）：PUT 推送 + GET 增量，mock 返回空（dev 无真实实体）。
    if (path == '/vault/daily-entities' && options.method == 'PUT') {
      return _reply(handler, options, _ok({'pushed': 0, 'skipped': 0}));
    }
    if (path == '/vault/daily-entities/changes' && options.method == 'GET') {
      return _reply(handler, options, _ok({
        'schedules': <Map<String, dynamic>>[],
        'quickNotes': <Map<String, dynamic>>[],
        'reviewAnswers': <Map<String, dynamic>>[],
        'dailyFocuses': <Map<String, dynamic>>[],
        'nextCursor': DateTime.now().toUtc().toIso8601String(),
        'hasMore': false,
      }));
    }
    // 阶段八：附件上传（POST /vault/attachments，multipart）。
    if (path == '/vault/attachments' && options.method == 'POST') {
      return _reply(handler, options, _uploadAttachment(options.data));
    }
    // 阶段八：附件下载（GET /vault/attachments/{hash}，返回裸字节流，非信封）。
    if (path.startsWith('/vault/attachments/') && options.method == 'GET') {
      return _downloadAttachment(handler, options, path);
    }
    // 阶段九：冲突列表（GET /vault/conflicts）。
    if (path == '/vault/conflicts' && options.method == 'GET') {
      return _reply(handler, options, _ok(_listConflicts()));
    }
    // 阶段九：解决冲突（POST /vault/conflicts/{id}/resolve）。
    if (path.startsWith('/vault/conflicts/') &&
        path.endsWith('/resolve') &&
        options.method == 'POST') {
      return _reply(handler, options, _resolveConflict(options.data));
    }

    handler.next(options);
  }

  /// 阶段九：mock 冲突列表（1 条 demo 冲突，含本机/云端双方内容）。
  List<Map<String, dynamic>> _listConflicts() {
    return [
      {
        'conflictId': 1,
        'vaultPath': 'Notes/冲突演示.md',
        'mineHash': 'mine-demo-hash-0000000000000000000000000000000000000000',
        'theirsHash': 'theirs-demo-hash-00000000000000000000000000000000000000',
        'theirsContent': '# 云端版本\n这是另一台设备编辑的内容。',
        'conflictCopyPath': 'Notes/冲突演示.conflict-20260620T120000.md',
        'status': 'open',
        'createdAt': MockApiData.serverTime,
      }
    ];
  }

  /// 阶段九：mock 解决冲突 —— 返回 keepMine 时的本机正本 / keepTheirs 时的云端正本。
  Map<String, dynamic> _resolveConflict(Object? body) {
    final data = body is Map ? body : const {};
    final strategy = data['strategy']?.toString() ?? 'keepMine';
    final content = data['content']?.toString() ?? '# 本机版本';
    final vaultPath = 'Notes/冲突演示.md';
    if (strategy == 'keepTheirs') {
      return _ok({
        'vaultPath': vaultPath,
        'content': '# 云端版本\n这是另一台设备编辑的内容。',
        'contentHash':
            'theirs-demo-hash-00000000000000000000000000000000000000',
        'version': 3,
        'serverMtime': MockApiData.serverTime,
        'size': 30,
      });
    }
    // keepMine：返回本机内容作为新正本。
    return _ok({
      'vaultPath': vaultPath,
      'content': content,
      'contentHash': 'mine-resolved-hash-00000000000000000000000000000000000',
      'version': 3,
      'serverMtime': MockApiData.serverTime,
      'size': content.length,
    });
  }

  Map<String, dynamic> _login(Object? body) {
    if (scenario == 'login_fail') {
      return _fail(401, '账号或密码错误');
    }
    if (scenario == 'no_permission') {
      return _fail(403, '当前账号暂无移动端同步权限');
    }
    final data = body is Map ? body : const {};
    final username = data['username']?.toString().trim();
    final password = data['password']?.toString();
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _fail(400, '请输入账号和密码');
    }
    return _ok({
      'userId': MockApiData.userId,
      'username': username,
      'email': MockApiData.email,
      'token': MockApiData.token,
      'expiresAt': '2026-07-18T09:41:00.000Z',
    });
  }

  Map<String, dynamic> _registerDevice(Object? body) {
    final data = body is Map ? body : const {};
    final deviceId = data['deviceId']?.toString();
    if (deviceId == null || deviceId.isEmpty) {
      return _fail(400, 'deviceId 不能为空');
    }
    final device = {
      'id': 9001,
      'deviceId': deviceId,
      'name': data['name']?.toString().isNotEmpty == true
          ? data['name'].toString()
          : 'LifeScale Mobile',
      'platform': data['platform']?.toString().isNotEmpty == true
          ? data['platform'].toString()
          : 'android',
      'lastSyncedAt': MockApiData.serverTime,
      'lastSeenAt': MockApiData.serverTime,
    };
    _registeredDevices
      ..removeWhere((item) => item['deviceId'] == deviceId)
      ..add(device);
    return _ok(device);
  }

  Map<String, dynamic> _changes() {
    if (scenario == 'empty') {
      return _ok({
        'changes': <Map<String, dynamic>>[],
        'serverTime': MockApiData.serverTime,
        'nextCursor': MockApiData.nextCursor,
        'hasMore': false,
      });
    }
    final files = _fileStore.values.toList();
    return _ok({
      'changes': files
          .map(
            (file) => {
              'vaultPath': file.vaultPath,
              'contentHash': file.contentHash,
              'version': file.version,
              'serverMtime': file.serverMtime,
              'status': file.status,
              'size': file.size,
            },
          )
          .toList(),
      'serverTime': MockApiData.serverTime,
      'nextCursor': MockApiData.nextCursor,
      'hasMore': false,
    });
  }

  Map<String, dynamic> _file(Object? pathValue) {
    final path = pathValue?.toString();
    if (path == null || path.isEmpty) return _fail(400, 'path 不能为空');
    if (scenario == 'no_permission') {
      return _fail(403, '当前账号暂无今日查看权限');
    }
    // empty 态：今天 Daily 不存在（其余 Vault 文件正常）。
    if (scenario == 'empty' && path == MockApiData.todayPath) {
      return _fail(404, '今天还没有 Daily 内容');
    }
    if (scenario == 'server_error') {
      return _fail(500, '今日内容服务暂时不可用');
    }
    if (scenario == 'partial_fail' && path != MockApiData.todayPath) {
      return _fail(503, '部分文件下载失败，请稍后重试');
    }
    final file = _fileStore[path];
    if (file == null) return _fail(404, '文件不存在或已删除');
    return _ok({
      'vaultPath': file.vaultPath,
      'content': file.content,
      'contentHash': file.contentHash,
      'version': file.version,
      'serverMtime': file.serverMtime,
      'size': file.size,
    });
  }

  Map<String, dynamic> _pushFile(Object? body) {
    if (scenario == 'no_permission') {
      return _fail(403, '当前账号暂无今日编辑权限');
    }
    if (scenario == 'server_error' || scenario == 'partial_fail') {
      return _fail(500, '保存服务暂时不可用');
    }

    final data = body is Map ? body : const {};
    final vaultPath = data['vaultPath']?.toString();
    final content = data['content']?.toString();
    if (vaultPath == null || vaultPath.isEmpty) {
      return _fail(400, 'vaultPath 不能为空');
    }
    if (content == null) {
      return _fail(400, 'content 不能为空');
    }

    final store = _fileStore;
    final existing = store[vaultPath];
    final ifMatchHash = data['ifMatchHash']?.toString();
    // 模拟乐观锁：scenario=conflict 或 base hash 与服务端不一致 → 冲突副本。
    if (scenario == 'conflict' ||
        (existing != null &&
            ifMatchHash != null &&
            ifMatchHash.isNotEmpty &&
            ifMatchHash != existing.contentHash)) {
      return _ok({
        'outcome': 'conflict',
        'data': null,
        'conflict': {
          'baseHash': ifMatchHash,
          'theirsHash': existing?.contentHash ?? 'mock-missing',
          'theirsContent': existing?.content,
          'conflictCopyPath': '$vaultPath.conflict',
          'conflictId': 1,
        },
      });
    }

    final file = MockVaultFile(
      vaultPath: vaultPath,
      content: content,
      version: (existing?.version ?? 0) + 1,
      serverMtime: DateTime.now().toUtc().toIso8601String(),
    );
    store[vaultPath] = file;
    return _ok({
      'outcome': existing == null ? 'created' : 'ok',
      'data': {
        'vaultPath': file.vaultPath,
        'content': file.content,
        'contentHash': file.contentHash,
        'version': file.version,
        'serverMtime': file.serverMtime,
        'size': file.size,
      },
      'conflict': null,
    });
  }

  Map<String, dynamic> _currentUser() => {
    'id': MockApiData.userId,
    'username': MockApiData.username,
    'email': MockApiData.email,
  };

  /// 阶段八：模拟附件上传。从 multipart FormData 提取字节，算 hash，返回 AttachmentUploadResult。
  Map<String, dynamic> _uploadAttachment(Object? body) {
    if (scenario == 'server_error' || scenario == 'partial_fail') {
      return _fail(500, '附件服务暂时不可用');
    }
    // body 为 FormData（dio 序列化）。mock 无法可靠还原字节，故用固定 demo hash + 推断 size。
    // 真实 hash 由客户端本地已计算并写缓存，此处仅满足 DTO 契约。
    final hash = MockApiData.demoAttachmentHash;
    return _ok({
      'hash': hash,
      'size': 1234,
      'path': 'attachments/$hash',
    });
  }

  /// 阶段八：模拟附件下载，返回裸字节流（1x1 蓝色 PNG，非信封）。
  /// 这样 mock 模式下笔记内的图片引用能渲染为实图，而非缺图占位。
  void _downloadAttachment(
    RequestInterceptorHandler handler,
    RequestOptions options,
    String path,
  ) {
    final bytes = MockApiData.demoPngBytes;
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: bytes,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/octet-stream'],
        }),
      ),
    );
  }

  Map<String, MockVaultFile> get _fileStore {
    return _files ??= {
      for (final file in MockApiData.files()) file.vaultPath: file,
    };
  }

  Map<String, dynamic> _ok(Object? data) => {
    'code': 200,
    'success': true,
    'message': 'ok',
    'data': data,
  };

  Map<String, dynamic> _fail(int code, String message) => {
    'code': code,
    'success': false,
    'message': message,
    'data': null,
  };

  void _reply(
    RequestInterceptorHandler handler,
    RequestOptions options,
    Map<String, dynamic> body,
  ) {
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: body['code'] as int,
        data: body,
      ),
    );
  }
}
