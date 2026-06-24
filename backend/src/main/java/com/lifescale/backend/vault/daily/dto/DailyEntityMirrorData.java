package com.lifescale.backend.vault.daily.dto;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Daily 实体镜像 DTO（与本地 SQLite 行结构对齐，camelCase JSON key）。
 * 各实体用独立 record，settled/deleted/updatedAt 是 LWW 同步与游标的核心字段。
 */
public final class DailyEntityMirrorData {

    private DailyEntityMirrorData() {
    }

    /** 日程（任务 + 时间记录）。id = 客户端实体 UUID（LWW 身份键）。 */
    public record Schedule(
            String id,
            LocalDate date,
            String startTime,
            String endTime,
            String title,
            String category,
            String type,
            boolean completed,
            boolean focus,
            int sortOrder,
            boolean settled,
            boolean deleted,
            Instant updatedAt) {
    }

    /** 快速记录。id = 客户端实体 UUID。 */
    public record QuickNote(
            String id,
            LocalDate date,
            String content,
            boolean settled,
            boolean deleted,
            Instant updatedAt) {
    }

    /** 复盘答案（每题一条）。id = questionId（一题一条）。 */
    public record ReviewAnswer(
            String id,
            LocalDate date,
            String questionId,
            String title,
            String content,
            boolean settled,
            boolean deleted,
            Instant updatedAt) {
    }

    /** 今日重点（自由文本，单条/日）。date 为业务身份。 */
    public record DailyFocus(
            LocalDate date,
            String content,
            boolean settled,
            boolean deleted,
            Instant updatedAt) {
    }
}
