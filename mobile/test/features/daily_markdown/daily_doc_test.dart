import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_doc_factory.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_doc_parser.dart';
import 'package:lifescale_mobile/features/daily_markdown/data/daily_doc_serializer.dart';
import 'package:lifescale_mobile/shared/constants/markdown.dart';

const date = '2026-06-17';

/// 与桌面端 dailyDoc.test.ts 中 SAMPLE 一致（docs/06 §3.3 带 ID 完整示例）。
const sample = '''# 2026年6月17日 周二

## 今日重点
- 写完设计文档 <!-- focus -->
- 09:00-10:00 写周报 <!-- sid:aaa -->

## 今日日程
- [x] 09:00-10:00 写周报（工作） <!-- sid:aaa -->
- [ ] 14:00-15:00 健身（生活） <!-- sid:bbb -->

### 时间记录
- 10:00-10:30 开会（记录） <!-- sid:ccc -->

## 快速记录
- 09:30 想到一个点子 <!-- qn:q1 -->
- 11:15 买咖啡 <!-- qn:q2 -->

## 今日复盘
### 今天完成了什么 <!-- rv:r1 -->
  写完了文档
  还测了一遍

### 哪里可以改进 <!-- rv:r2 -->
  早起
''';

const seed = '''# 2026年6月17日 周二

## 今日重点
暂无今日重点。

## 今日日程
暂无日程。

## 快速记录
暂无快速记录。

## 今日复盘
暂无复盘内容。''';

const oldFile = '''# 2026年6月17日 周二

## 今日重点
- 写完设计文档

## 今日日程
- [x] 09:00-10:00 写周报（工作）

## 快速记录
- 09:30 想到一个点子

## 今日复盘
### 今天完成了什么
  写完了文档
''';

void main() {
  group('parseDailyDoc / serializeDailyDoc', () {
    test('空模板 → 空模型，不脏', () {
      final res = DailyDocParser.parse(seed, date: date);
      expect(res.model.title, '2026年6月17日 周二');
      expect(res.model.focus, isNull);
      expect(res.model.schedules, isEmpty);
      expect(res.model.quickNotes, isEmpty);
      expect(res.model.review, isEmpty);
      expect(res.dirty, isFalse);
    });

    test('空模型序列化 → 含占位、不带注释', () {
      final md = DailyDocSerializer.serialize(
        DailyDocFactory.createEmpty('2026年6月17日 周二'),
      );
      expect(md, contains('## 今日重点\n暂无今日重点。'));
      expect(md, contains('## 今日日程\n暂无日程。'));
      expect(md, contains('## 快速记录\n暂无快速记录。'));
      expect(md, contains('## 今日复盘\n暂无复盘内容。'));
      expect(md.contains('<!--'), isFalse);
      expect(md, seed);
    });

    test('重点 + 日程同名：靠 sid 关联，自由重点单独保留', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      expect(model.focus, '写完设计文档');
      final weekly = model.schedules.firstWhere((s) => s.id == 'aaa');
      expect(weekly.title, '写周报');
      expect(weekly.focus, isTrue);
      expect(weekly.completed, isTrue);
      expect(weekly.type, ScheduleType.task);
      expect(weekly.category, ScheduleCategory.work);
      final gym = model.schedules.firstWhere((s) => s.id == 'bbb');
      expect(gym.completed, isFalse);
      expect(gym.focus, isNull);
    });

    test('时间记录子段 → type=note', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      final meeting = model.schedules.firstWhere((s) => s.id == 'ccc');
      expect(meeting.type, ScheduleType.note);
      expect(meeting.startTime, '10:00');
      expect(meeting.endTime, '10:30');
    });

    test('快速记录：内容与由 createdAt 派生的 HH:mm', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      expect(model.quickNotes, hasLength(2));
      final idea = model.quickNotes.firstWhere((q) => q.id == 'q1');
      expect(idea.content, '想到一个点子');
      expect(idea.createdAt, '2026-06-17T09:30:00.000');
    });

    test('多行复盘答案（缩进）正确合并', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      expect(model.review, hasLength(2));
      final r1 = model.review.firstWhere((r) => r.questionId == 'r1');
      expect(r1.title, '今天完成了什么');
      expect(r1.content, '写完了文档\n还测了一遍');
      final r2 = model.review.firstWhere((r) => r.questionId == 'r2');
      expect(r2.content, '早起');
    });

    test('段内行序 = sortOrder', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      final tasks = model.schedules
          .where((s) => s.type != ScheduleType.note)
          .toList();
      expect(tasks[0].sortOrder, 0);
      expect(tasks[1].sortOrder, 1);
      final note = model.schedules.firstWhere(
        (s) => s.type == ScheduleType.note,
      );
      expect(note.sortOrder, 2);
    });

    test('移动行顺序：重排后序列化→解析顺序保留', () {
      final parsed = DailyDocParser.parse(sample, date: date).model;
      final aaa = parsed.schedules.firstWhere((s) => s.id == 'aaa');
      final bbb = parsed.schedules.firstWhere((s) => s.id == 'bbb');
      final ccc = parsed.schedules.firstWhere((s) => s.id == 'ccc');
      final reordered = parsed.copyWith(
        schedules: [
          bbb.copyWith(sortOrder: 0),
          aaa.copyWith(sortOrder: 1),
          ccc.copyWith(sortOrder: 2),
        ],
      );
      final md = DailyDocSerializer.serialize(reordered);
      final model = DailyDocParser.parse(md, date: date).model;
      final tasks = model.schedules
          .where((s) => s.type != ScheduleType.note)
          .toList();
      expect(tasks[0].id, 'bbb');
      expect(tasks[1].id, 'aaa');
    });

    test('删除行：序列化后该条消失', () {
      final parsed = DailyDocParser.parse(sample, date: date).model;
      final deleted = parsed.copyWith(
        schedules: parsed.schedules.where((s) => s.id != 'bbb').toList(),
      );
      final md = DailyDocSerializer.serialize(deleted);
      final model = DailyDocParser.parse(md, date: date).model;
      expect(model.schedules.where((s) => s.id == 'bbb'), isEmpty);
      expect(model.schedules, hasLength(2));
    });

    test('往返等价：serialize(parse(serialize(parse(x)))) 稳定且不再 dirty', () {
      final once = DailyDocSerializer.serialize(
        DailyDocParser.parse(sample, date: date).model,
      );
      final twice = DailyDocSerializer.serialize(
        DailyDocParser.parse(once, date: date).model,
      );
      expect(twice, once);
      expect(DailyDocParser.parse(once, date: date).dirty, isFalse);
      expect(
        DailyDocParser.parse(once, date: date).model,
        DailyDocParser.parse(twice, date: date).model,
      );
    });

    test('老文件无 ID → 补 ID 并标 dirty；补完后再解析不脏', () {
      final res = DailyDocParser.parse(oldFile, date: date);
      expect(res.dirty, isTrue);
      expect(res.model.focus, '写完设计文档');
      expect(res.model.schedules.first.id, isNotEmpty);
      expect(res.model.quickNotes.first.id, isNotEmpty);
      expect(res.model.review.first.questionId, isNotEmpty);

      final withIds = DailyDocSerializer.serialize(res.model);
      final reparsed = DailyDocParser.parse(withIds, date: date);
      expect(reparsed.dirty, isFalse);
      expect(reparsed.model.schedules.first.title, '写周报');
      expect(reparsed.model.review.first.content, '写完了文档');
    });

    test('容错：无段间空行（REST 旧生成器格式）也能解析', () {
      final noBlanks = sample.replaceAll('\n\n', '\n');
      final model = DailyDocParser.parse(noBlanks, date: date).model;
      expect(model.schedules, hasLength(3));
      expect(model.quickNotes, hasLength(2));
      expect(model.review, hasLength(2));
    });
  });

  /// docs/09 §12.1 沉淀纯净文法（零注释，与桌面 serializeCleanDailyDoc/parseCleanMd 对齐）。
  group('serializeClean / parseClean（沉淀纯净文法）', () {
    const cleanSample = '''# 2026年6月17日 周二

## 今日重点
- 写完设计文档
- 09:00-10:00 写周报

## 今日日程
- [x] 09:00-10:00 写周报（工作）
- [ ] 14:00-15:00 健身（生活）

### 时间记录
- 10:00-10:30 开会（记录）

## 快速记录
- 09:30 想到一个点子
- 11:15 买咖啡

## 今日复盘
### 今天完成了什么
  写完了文档
  还测了一遍

### 哪里可以改进
  早起
''';

    test('serializeClean：零 `<!-- -->` 注释', () {
      final model = DailyDocParser.parse(sample, date: date).model;
      final md = DailyDocSerializer.serializeClean(model);
      expect(md.contains('<!--'), isFalse);
      expect(md.contains('## 今日重点'), isTrue);
      expect(md.contains('## 今日日程'), isTrue);
      expect(md.contains('### 时间记录'), isTrue);
    });

    test('serializeClean 空模型：含占位、零注释', () {
      final md = DailyDocSerializer.serializeClean(
        DailyDocFactory.createEmpty('2026年6月17日 周二'),
      );
      expect(md.contains('暂无今日重点。'), isTrue);
      expect(md.contains('暂无日程。'), isTrue);
      expect(md.contains('<!--'), isFalse);
    });

    test('parseClean：实体内容等价（标题/时间段/分类/完成/重点/复盘）', () {
      final res = DailyDocParser.parseClean(cleanSample, date: date);
      expect(res.dirty, isFalse); // 纯净文法无 ID 需补
      expect(res.model.focus, '写完设计文档');
      expect(res.model.schedules, hasLength(3));
      final weekly = res.model.schedules.firstWhere(
        (s) => s.startTime == '09:00' && s.title == '写周报',
      );
      expect(weekly.completed, isTrue);
      expect(weekly.category, ScheduleCategory.work);
      expect(weekly.type, ScheduleType.task);
      // 重点引用靠内容指纹匹配 → focus
      expect(weekly.focus, isTrue);
      final meeting = res.model.schedules.firstWhere((s) => s.type == ScheduleType.note);
      expect(meeting.startTime, '10:00');
      expect(res.model.quickNotes, hasLength(2));
      expect(res.model.quickNotes.first.content, '想到一个点子');
      expect(res.model.review, hasLength(2));
      expect(res.model.review.first.title, '今天完成了什么');
      expect(res.model.review.first.content, '写完了文档\n还测了一遍');
    });

    test('纯净往返：serializeClean(parseClean(x)) 实体内容等价', () {
      final parsed = DailyDocParser.parseClean(cleanSample, date: date).model;
      final reserialized = DailyDocSerializer.serializeClean(parsed);
      final reparsed = DailyDocParser.parseClean(reserialized, date: date).model;
      // 比较关键字段（ID 因临时分配每次不同，跳过）
      expect(reparsed.focus, parsed.focus);
      expect(
        reparsed.schedules
            .map((s) => '${s.startTime}-${s.endTime} ${s.title} ${s.category.label} ${s.completed}')
            .toList(),
        parsed.schedules
            .map((s) => '${s.startTime}-${s.endTime} ${s.title} ${s.category.label} ${s.completed}')
            .toList(),
      );
      expect(
        reparsed.quickNotes.map((q) => '${q.createdAt} ${q.content}').toList(),
        parsed.quickNotes.map((q) => '${q.createdAt} ${q.content}').toList(),
      );
    });
  });
}
