package com.lifescale.backend.vault.daily.dto;

import java.util.List;

/**
 * Daily 实体同步请求/响应 DTO（docs/09 §9.3 当天实体 LWW 同步）。
 */
public final class DailyEntitySyncDto {

    private DailyEntitySyncDto() {
    }

    /** 推送当天未沉淀实体（批量，4 类一次推）。LWW：服务端按 updatedAt 取最新。 */
    public record DailyEntityPushPayload(
            List<DailyEntityMirrorData.Schedule> schedules,
            List<DailyEntityMirrorData.QuickNote> quickNotes,
            List<DailyEntityMirrorData.ReviewAnswer> reviewAnswers,
            List<DailyEntityMirrorData.DailyFocus> dailyFocuses,
            String deviceId) {
    }

    /** /api/vault/daily-entities/changes 返回：4 类增量变更 + 游标。 */
    public record DailyEntityChangesData(
            List<DailyEntityMirrorData.Schedule> schedules,
            List<DailyEntityMirrorData.QuickNote> quickNotes,
            List<DailyEntityMirrorData.ReviewAnswer> reviewAnswers,
            List<DailyEntityMirrorData.DailyFocus> dailyFocuses,
            String nextCursor,
            boolean hasMore) {
    }

    /** 推送结果：覆盖数 / 丢弃数（LWW 旧版本被跳过）。 */
    public record DailyEntitySyncResult(int pushed, int skipped) {
    }
}
