package com.lifescale.backend.vault.daily.service;

import com.lifescale.backend.vault.daily.dto.DailyEntityMirrorData;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityChangesData;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntityPushPayload;
import com.lifescale.backend.vault.daily.dto.DailyEntitySyncDto.DailyEntitySyncResult;
import com.lifescale.backend.vault.daily.entity.DailyFocusMirror;
import com.lifescale.backend.vault.daily.entity.QuickNoteMirror;
import com.lifescale.backend.vault.daily.entity.ReviewAnswerMirror;
import com.lifescale.backend.vault.daily.entity.ScheduleMirror;
import com.lifescale.backend.vault.daily.repository.DailyFocusMirrorRepository;
import com.lifescale.backend.vault.daily.repository.QuickNoteMirrorRepository;
import com.lifescale.backend.vault.daily.repository.ReviewAnswerMirrorRepository;
import com.lifescale.backend.vault.daily.repository.ScheduleMirrorRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DateTimeException;
import java.time.Instant;
import java.util.List;

/**
 * Daily 当天实体同步服务（docs/09 §9.3）。
 *
 * 仅同步当天未沉淀数据（settled=false），合并策略 last-write-wins per entity
 * （按 updatedAt 取最新，无需三方合并）。墓碑 status=deleted 传播。沉淀后实体不再变。
 */
@Service
public class DailyEntitySyncService {

    private static final Logger log = LoggerFactory.getLogger(DailyEntitySyncService.class);

    private final ScheduleMirrorRepository scheduleRepo;
    private final QuickNoteMirrorRepository quickNoteRepo;
    private final ReviewAnswerMirrorRepository reviewAnswerRepo;
    private final DailyFocusMirrorRepository dailyFocusRepo;

    public DailyEntitySyncService(ScheduleMirrorRepository scheduleRepo,
                                  QuickNoteMirrorRepository quickNoteRepo,
                                  ReviewAnswerMirrorRepository reviewAnswerRepo,
                                  DailyFocusMirrorRepository dailyFocusRepo) {
        this.scheduleRepo = scheduleRepo;
        this.quickNoteRepo = quickNoteRepo;
        this.reviewAnswerRepo = reviewAnswerRepo;
        this.dailyFocusRepo = dailyFocusRepo;
    }

    // ============================ 推送（LWW per entity）============================

    /**
     * 批量推送 4 类当天实体。对每条：服务端无记录→新建；有记录且 payload.updatedAt 晚于
     * 服务端→覆盖；否则丢弃（保留服务端较新版本）。
     */
    @Transactional
    public DailyEntitySyncResult pushEntities(Long userId, DailyEntityPushPayload payload) {
        int pushed = 0;
        int skipped = 0;
        if (payload.schedules() != null) {
            for (DailyEntityMirrorData.Schedule s : payload.schedules()) {
                if (upsertScheduleLww(userId, s)) pushed++;
                else skipped++;
            }
        }
        if (payload.quickNotes() != null) {
            for (DailyEntityMirrorData.QuickNote q : payload.quickNotes()) {
                if (upsertQuickNoteLww(userId, q)) pushed++;
                else skipped++;
            }
        }
        if (payload.reviewAnswers() != null) {
            for (DailyEntityMirrorData.ReviewAnswer r : payload.reviewAnswers()) {
                if (upsertReviewAnswerLww(userId, r)) pushed++;
                else skipped++;
            }
        }
        if (payload.dailyFocuses() != null) {
            for (DailyEntityMirrorData.DailyFocus f : payload.dailyFocuses()) {
                if (upsertDailyFocusLww(userId, f)) pushed++;
                else skipped++;
            }
        }
        log.debug("实体推送 userId={} pushed={} skipped={}", userId, pushed, skipped);
        return new DailyEntitySyncResult(pushed, skipped);
    }

    private boolean upsertScheduleLww(Long userId, DailyEntityMirrorData.Schedule s) {
        ScheduleMirror current = scheduleRepo.findByUserIdAndEntityId(userId, s.id()).orElse(null);
        if (current == null) {
            scheduleRepo.save(buildSchedule(userId, s));
            return true;
        }
        if (s.updatedAt() != null && current.getUpdatedAt() != null
                && !s.updatedAt().isAfter(current.getUpdatedAt())) {
            return false; // 服务端较新，丢弃
        }
        applySchedule(current, userId, s);
        scheduleRepo.save(current);
        return true;
    }

    private boolean upsertQuickNoteLww(Long userId, DailyEntityMirrorData.QuickNote q) {
        QuickNoteMirror current = quickNoteRepo.findByUserIdAndEntityId(userId, q.id()).orElse(null);
        if (current == null) {
            quickNoteRepo.save(buildQuickNote(userId, q));
            return true;
        }
        if (q.updatedAt() != null && current.getUpdatedAt() != null
                && !q.updatedAt().isAfter(current.getUpdatedAt())) {
            return false;
        }
        applyQuickNote(current, userId, q);
        quickNoteRepo.save(current);
        return true;
    }

    private boolean upsertReviewAnswerLww(Long userId, DailyEntityMirrorData.ReviewAnswer r) {
        ReviewAnswerMirror current = reviewAnswerRepo.findByUserIdAndEntityId(userId, r.id()).orElse(null);
        if (current == null) {
            reviewAnswerRepo.save(buildReviewAnswer(userId, r));
            return true;
        }
        if (r.updatedAt() != null && current.getUpdatedAt() != null
                && !r.updatedAt().isAfter(current.getUpdatedAt())) {
            return false;
        }
        applyReviewAnswer(current, userId, r);
        reviewAnswerRepo.save(current);
        return true;
    }

    private boolean upsertDailyFocusLww(Long userId, DailyEntityMirrorData.DailyFocus f) {
        DailyFocusMirror current = dailyFocusRepo.findByUserIdAndDate(userId, f.date()).orElse(null);
        if (current == null) {
            dailyFocusRepo.save(buildDailyFocus(userId, f));
            return true;
        }
        if (f.updatedAt() != null && current.getUpdatedAt() != null
                && !f.updatedAt().isAfter(current.getUpdatedAt())) {
            return false;
        }
        applyDailyFocus(current, userId, f);
        dailyFocusRepo.save(current);
        return true;
    }

    // ---- entity 构造/应用（payload → entity）----

    private ScheduleMirror buildSchedule(Long userId, DailyEntityMirrorData.Schedule s) {
        ScheduleMirror e = new ScheduleMirror();
        applySchedule(e, userId, s);
        return e;
    }

    private void applySchedule(ScheduleMirror e, Long userId, DailyEntityMirrorData.Schedule s) {
        e.setUserId(userId);
        e.setEntityId(s.id());
        e.setDate(s.date());
        e.setStartTime(s.startTime());
        e.setEndTime(s.endTime());
        e.setTitle(s.title());
        e.setCategory(s.category());
        e.setType(s.type());
        e.setCompleted(s.completed());
        e.setFocus(s.focus());
        e.setSortOrder(s.sortOrder());
        e.setSettled(s.settled());
        e.setStatus(s.deleted() ? "deleted" : "active");
        if (s.updatedAt() != null) e.setUpdatedAt(s.updatedAt());
    }

    private QuickNoteMirror buildQuickNote(Long userId, DailyEntityMirrorData.QuickNote q) {
        QuickNoteMirror e = new QuickNoteMirror();
        applyQuickNote(e, userId, q);
        return e;
    }

    private void applyQuickNote(QuickNoteMirror e, Long userId, DailyEntityMirrorData.QuickNote q) {
        e.setUserId(userId);
        e.setEntityId(q.id());
        e.setDate(q.date());
        e.setContent(q.content());
        e.setSettled(q.settled());
        e.setStatus(q.deleted() ? "deleted" : "active");
        if (q.updatedAt() != null) e.setUpdatedAt(q.updatedAt());
    }

    private ReviewAnswerMirror buildReviewAnswer(Long userId, DailyEntityMirrorData.ReviewAnswer r) {
        ReviewAnswerMirror e = new ReviewAnswerMirror();
        applyReviewAnswer(e, userId, r);
        return e;
    }

    private void applyReviewAnswer(ReviewAnswerMirror e, Long userId, DailyEntityMirrorData.ReviewAnswer r) {
        e.setUserId(userId);
        e.setEntityId(r.id());
        e.setDate(r.date());
        e.setQuestionId(r.questionId());
        e.setTitle(r.title());
        e.setContent(r.content());
        e.setSettled(r.settled());
        e.setStatus(r.deleted() ? "deleted" : "active");
        if (r.updatedAt() != null) e.setUpdatedAt(r.updatedAt());
    }

    private DailyFocusMirror buildDailyFocus(Long userId, DailyEntityMirrorData.DailyFocus f) {
        DailyFocusMirror e = new DailyFocusMirror();
        applyDailyFocus(e, userId, f);
        return e;
    }

    private void applyDailyFocus(DailyFocusMirror e, Long userId, DailyEntityMirrorData.DailyFocus f) {
        e.setUserId(userId);
        e.setDate(f.date());
        e.setContent(f.content());
        e.setSettled(f.settled());
        e.setStatus(f.deleted() ? "deleted" : "active");
        if (f.updatedAt() != null) e.setUpdatedAt(f.updatedAt());
    }

    // ============================ 拉取（增量游标）============================

    /**
     * 增量拉取 4 类实体变更。游标容错（since 非法→EPOCH，仿 VaultService.changes）。
     * nextCursor 取本页最后一条 updatedAt（4 类合并取最大）；空页取 now。
     */
    @Transactional(readOnly = true)
    public DailyEntityChangesData getChanges(Long userId, String since, Integer limit) {
        Instant sinceInstant = parseCursor(since);
        int size = Math.min(Math.max(limit == null ? 200 : limit, 1), 500);
        PageRequest page = PageRequest.of(0, size);

        Page<ScheduleMirror> schedules = scheduleRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(userId, sinceInstant, page);
        Page<QuickNoteMirror> quickNotes = quickNoteRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(userId, sinceInstant, page);
        Page<ReviewAnswerMirror> reviewAnswers = reviewAnswerRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(userId, sinceInstant, page);
        Page<DailyFocusMirror> dailyFocuses = dailyFocusRepo.findByUserIdAndUpdatedAtAfterOrderByUpdatedAtAsc(userId, sinceInstant, page);

        List<DailyEntityMirrorData.Schedule> scheduleDto = schedules.getContent().stream().map(this::toScheduleDto).toList();
        List<DailyEntityMirrorData.QuickNote> quickNoteDto = quickNotes.getContent().stream().map(this::toQuickNoteDto).toList();
        List<DailyEntityMirrorData.ReviewAnswer> reviewAnswerDto = reviewAnswers.getContent().stream().map(this::toReviewAnswerDto).toList();
        List<DailyEntityMirrorData.DailyFocus> dailyFocusDto = dailyFocuses.getContent().stream().map(this::toDailyFocusDto).toList();

        Instant maxCursor = maxUpdatedAt(
                lastUpdatedAt(schedules), lastUpdatedAt(quickNotes),
                lastUpdatedAt(reviewAnswers), lastUpdatedAt(dailyFocuses));
        String nextCursor = (maxCursor != null ? maxCursor : Instant.now()).toString();
        boolean hasMore = schedules.hasNext() || quickNotes.hasNext() || reviewAnswers.hasNext() || dailyFocuses.hasNext();

        return new DailyEntityChangesData(scheduleDto, quickNoteDto, reviewAnswerDto, dailyFocusDto, nextCursor, hasMore);
    }

    private Instant parseCursor(String since) {
        if (since == null || since.isBlank()) return Instant.EPOCH;
        try {
            return Instant.parse(since);
        } catch (DateTimeException e) {
            return Instant.EPOCH;
        }
    }

    private Instant lastUpdatedAt(Page<?> page) {
        if (page.isEmpty()) return null;
        Object last = page.getContent().get(page.getNumberOfElements() - 1);
        if (last instanceof ScheduleMirror s) return s.getUpdatedAt();
        if (last instanceof QuickNoteMirror q) return q.getUpdatedAt();
        if (last instanceof ReviewAnswerMirror r) return r.getUpdatedAt();
        if (last instanceof DailyFocusMirror f) return f.getUpdatedAt();
        return null;
    }

    private Instant maxUpdatedAt(Instant... values) {
        Instant max = null;
        for (Instant v : values) {
            if (v != null && (max == null || v.isAfter(max))) max = v;
        }
        return max;
    }

    // ---- entity → DTO ----

    private DailyEntityMirrorData.Schedule toScheduleDto(ScheduleMirror e) {
        return new DailyEntityMirrorData.Schedule(
                e.getEntityId(), e.getDate(), e.getStartTime(), e.getEndTime(),
                e.getTitle(), e.getCategory(), e.getType(), e.isCompleted(),
                e.isFocus(), e.getSortOrder(), e.isSettled(),
                "deleted".equals(e.getStatus()), e.getUpdatedAt());
    }

    private DailyEntityMirrorData.QuickNote toQuickNoteDto(QuickNoteMirror e) {
        return new DailyEntityMirrorData.QuickNote(
                e.getEntityId(), e.getDate(), e.getContent(),
                e.isSettled(), "deleted".equals(e.getStatus()), e.getUpdatedAt());
    }

    private DailyEntityMirrorData.ReviewAnswer toReviewAnswerDto(ReviewAnswerMirror e) {
        return new DailyEntityMirrorData.ReviewAnswer(
                e.getEntityId(), e.getDate(), e.getQuestionId(), e.getTitle(),
                e.getContent(), e.isSettled(), "deleted".equals(e.getStatus()), e.getUpdatedAt());
    }

    private DailyEntityMirrorData.DailyFocus toDailyFocusDto(DailyFocusMirror e) {
        return new DailyEntityMirrorData.DailyFocus(
                e.getDate(), e.getContent(), e.isSettled(),
                "deleted".equals(e.getStatus()), e.getUpdatedAt());
    }
}
