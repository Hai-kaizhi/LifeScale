package com.lifescale.backend.vault.daily;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.lifescale.backend.vault.daily.dto.DailyEntityMirrorData;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityChangesData;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityPushPayload;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntitySyncResult;
import com.lifescale.backend.vault.daily.entity.ScheduleMirror;
import com.lifescale.backend.vault.daily.repository.DailyFocusMirrorRepository;
import com.lifescale.backend.vault.daily.repository.QuickNoteMirrorRepository;
import com.lifescale.backend.vault.daily.repository.ReviewAnswerMirrorRepository;
import com.lifescale.backend.vault.daily.repository.ScheduleMirrorRepository;
import com.lifescale.backend.vault.daily.service.DailyEntitySyncService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Daily 实体同步 LWW 单测：mock 4 repository + 手动 new service。
 * 聚焦 pushEntities 的 LWW 分支（create/覆盖/丢弃）+ getChanges 游标容错。
 */
class DailyEntitySyncServiceTest {

    private static final Long USER_ID = 10001L;
    private static final LocalDate DATE = LocalDate.of(2026, 6, 23);

    private ScheduleMirrorRepository scheduleRepo;
    private QuickNoteMirrorRepository quickNoteRepo;
    private ReviewAnswerMirrorRepository reviewAnswerRepo;
    private DailyFocusMirrorRepository dailyFocusRepo;
    private DailyEntitySyncService service;

    @BeforeEach
    void setUp() {
        scheduleRepo = mock(ScheduleMirrorRepository.class);
        quickNoteRepo = mock(QuickNoteMirrorRepository.class);
        reviewAnswerRepo = mock(ReviewAnswerMirrorRepository.class);
        dailyFocusRepo = mock(DailyFocusMirrorRepository.class);
        service = new DailyEntitySyncService(scheduleRepo, quickNoteRepo, reviewAnswerRepo, dailyFocusRepo);
    }

    // ---- LWW 分支 ----

    @Test
    @DisplayName("LWW create：服务端无记录 → 新建")
    void pushSchedule_newEntity_creates() {
        Instant now = Instant.now();
        DailyEntityMirrorData.Schedule payload = new DailyEntityMirrorData.Schedule(
                "sch-1", DATE, "09:00", "10:00", "联调", "工作", "task",
                false, false, 0, false, false, now);
        when(scheduleRepo.findByUserIdAndEntityId(USER_ID, "sch-1")).thenReturn(Optional.empty());

        DailyEntitySyncResult result = service.pushEntities(USER_ID,
                new DailyEntityPushPayload(List.of(payload), null, null, null, "device-1"));

        assertThat(result.pushed()).isEqualTo(1);
        assertThat(result.skipped()).isEqualTo(0);
        verify(scheduleRepo).save(any(ScheduleMirror.class));
    }

    @Test
    @DisplayName("LWW 覆盖：payload.updatedAt 晚于服务端 → 覆盖")
    void pushSchedule_newer_overwrites() {
        Instant serverOld = Instant.parse("2026-06-23T09:00:00Z");
        Instant payloadNew = Instant.parse("2026-06-23T10:00:00Z");
        ScheduleMirror current = existingSchedule(serverOld);
        when(scheduleRepo.findByUserIdAndEntityId(USER_ID, "sch-1")).thenReturn(Optional.of(current));

        DailyEntityMirrorData.Schedule payload = scheduleDto(payloadNew, "新标题");
        DailyEntitySyncResult result = service.pushEntities(USER_ID,
                new DailyEntityPushPayload(List.of(payload), null, null, null, "device-1"));

        assertThat(result.pushed()).isEqualTo(1);
        assertThat(current.getTitle()).isEqualTo("新标题");
        verify(scheduleRepo).save(current);
    }

    @Test
    @DisplayName("LWW 丢弃：payload.updatedAt 不晚于服务端 → skip")
    void pushSchedule_older_skipped() {
        Instant serverNew = Instant.parse("2026-06-23T10:00:00Z");
        Instant payloadOld = Instant.parse("2026-06-23T09:00:00Z");
        ScheduleMirror current = existingSchedule(serverNew);
        when(scheduleRepo.findByUserIdAndEntityId(USER_ID, "sch-1")).thenReturn(Optional.of(current));

        DailyEntityMirrorData.Schedule payload = scheduleDto(payloadOld, "旧标题");
        DailyEntitySyncResult result = service.pushEntities(USER_ID,
                new DailyEntityPushPayload(List.of(payload), null, null, null, "device-1"));

        assertThat(result.skipped()).isEqualTo(1);
        assertThat(result.pushed()).isEqualTo(0);
        assertThat(current.getTitle()).isEqualTo("服务端标题"); // 未被覆盖
        verify(scheduleRepo, never()).save(any(ScheduleMirror.class));
    }

    @Test
    @DisplayName("删除传播：payload.deleted=true → status=deleted 落库")
    void pushSchedule_deleted_propagatesTombstone() {
        Instant now = Instant.now();
        when(scheduleRepo.findByUserIdAndEntityId(USER_ID, "sch-1")).thenReturn(Optional.empty());

        DailyEntityMirrorData.Schedule payload = new DailyEntityMirrorData.Schedule(
                "sch-1", DATE, "09:00", "10:00", "x", "工作", "task",
                false, false, 0, false, true, now); // deleted=true
        service.pushEntities(USER_ID, new DailyEntityPushPayload(List.of(payload), null, null, null, "d"));

        org.mockito.ArgumentCaptor<ScheduleMirror> captor = org.mockito.ArgumentCaptor.forClass(ScheduleMirror.class);
        verify(scheduleRepo).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo("deleted");
    }

    // ---- getChanges 游标容错 ----

    @Test
    @DisplayName("游标容错：since 为非法字符串 → 降级 EPOCH")
    void changes_dirtyCursor_fallsBackToEpoch() {
        // 4 个 repo 都返回空页（验证不 500 即可）
        when(scheduleRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));
        when(quickNoteRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));
        when(reviewAnswerRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));
        when(dailyFocusRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));

        DailyEntityChangesData data = service.getChanges(USER_ID, "mock-cursor-dirty", 200);
        assertThat(data.schedules()).isEmpty();
        assertThat(data.nextCursor()).isNotBlank();
        assertThat(data.hasMore()).isFalse();
    }

    @Test
    @DisplayName("getChanges 返回实体（含墓碑 status=deleted → deleted=true）")
    void changes_returnsEntitiesWithTombstone() {
        ScheduleMirror deleted = existingSchedule(Instant.parse("2026-06-23T08:00:00Z"));
        deleted.setStatus("deleted");
        when(scheduleRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(deleted), PageRequest.of(0, 200), 1));
        when(quickNoteRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));
        when(reviewAnswerRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));
        when(dailyFocusRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(eq(USER_ID), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 200), 0));

        DailyEntityChangesData data = service.getChanges(USER_ID, null, 200);
        assertThat(data.schedules()).hasSize(1);
        assertThat(data.schedules().get(0).deleted()).isTrue();
    }

    // ---- helpers ----

    private ScheduleMirror existingSchedule(Instant updatedAt) {
        ScheduleMirror e = new ScheduleMirror();
        e.setUserId(USER_ID);
        e.setEntityId("sch-1");
        e.setDate(DATE);
        e.setStartTime("09:00");
        e.setEndTime("10:00");
        e.setTitle("服务端标题");
        e.setCategory("工作");
        e.setType("task");
        e.setUpdatedAt(updatedAt);
        return e;
    }

    private DailyEntityMirrorData.Schedule scheduleDto(Instant updatedAt, String title) {
        return new DailyEntityMirrorData.Schedule(
                "sch-1", DATE, "09:00", "10:00", title, "工作", "task",
                false, false, 0, false, false, updatedAt);
    }
}
