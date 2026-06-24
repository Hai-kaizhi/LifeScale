import { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Button, Checkbox, Empty, Input, Modal, Select, Spin, Tag, Tooltip, message } from 'antd';
import {
  CalendarOutlined,
  CheckCircleFilled,
  CheckCircleOutlined,
  ClockCircleOutlined,
  CopyOutlined,
  DeleteOutlined,
  EditOutlined,
  ExclamationCircleFilled,
  FileDoneOutlined,
  MessageOutlined,
  PieChartOutlined,
  PlusOutlined,
  ReloadOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useCurrentDate } from '../../contexts/CurrentDateContext';
import { useDailyMarkdown } from '../../hooks/useDailyMarkdown';
import { useDailyReview } from '../../hooks/useDailyReview';
import { useMarkdownSettings } from '../../hooks/useMarkdownSettings';
import { useSettingsModal } from '../../hooks/useSettingsModal';
import { useLocalCalendarMonth } from '../../hooks/vault/useLocalCalendarMonth';
import { useVaultSync } from '../../hooks/useVaultSync';
import { MiniCalendar } from '../today/MiniCalendar';
import { QuickNotes } from '../today/QuickNotes';
import { settleDay } from '../../services/vault/settlementService';
import { settlementVaultPath } from '../../services/vault/dailyEntities';
import { DailyMarkdownModal } from './DailyMarkdownModal';
import type {
  CreateReviewQuestionSchemePayload,
  DailyReviewDetailData,
  ReviewQuestionScheme,
  SaveDailyReviewAnswerPayload,
  UpdateReviewQuestionSchemePayload,
} from '../../shared/types/dailyReview';
import type { QuickNote } from '../../shared/types/quickNote';
import type { Schedule } from '../../shared/types/schedule';
import { formatDate, formatDisplayDate, getWeekday } from '../../shared/utils/date';

type AnswerMap = Record<string, string>;

interface SchemeQuestionForm {
  clientId: string;
  id?: string;
  title: string;
  placeholder: string;
  required: boolean;
  maxLength: number;
}

interface ReviewSchemeManagerModalProps {
  open: boolean;
  schemes: ReviewQuestionScheme[];
  selectedSchemeId: string;
  saving: boolean;
  deletingId: string | null;
  onCancel: () => void;
  onUseScheme: (scheme: ReviewQuestionScheme, options?: { confirm?: boolean }) => void;
  onCreateScheme: (payload: CreateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  onUpdateScheme: (payload: UpdateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  onDeleteScheme: (id: string) => Promise<boolean>;
}

const STATUS_CONFIG = {
  not_started: { label: '未复盘', tone: 'danger' },
  filling: { label: '填写中', tone: 'primary' },
  backfilling: { label: '补写中', tone: 'warning' },
  completed: { label: '已复盘', tone: 'success' },
  readonly: { label: '只读', tone: 'muted' },
  no_permission: { label: '无权限', tone: 'muted' },
  saving: { label: '保存中', tone: 'primary' },
} as const;

const MAX_SCHEME_QUESTIONS = 4;

function getMonthKey(date: string): string {
  return dayjs(date).format('YYYY-MM');
}

function formatShortWeekday(date: string): string {
  return getWeekday(date).replace('星期', '周');
}

function formatNoteTime(note: QuickNote): string {
  return dayjs(note.createdAt).format('HH:mm');
}

function hasAnswerContent(answers: AnswerMap): boolean {
  return Object.values(answers).some((value) => value.trim().length > 0);
}

function answersFromDetail(detail: DailyReviewDetailData): AnswerMap {
  return Object.fromEntries(
    detail.review.answers.map((answer) => [answer.questionId, answer.content]),
  );
}

function getRequiredMissing(scheme: ReviewQuestionScheme | undefined, answers: AnswerMap): boolean {
  if (!scheme) {
    return true;
  }
  return scheme.questions.some((question) => question.required && !answers[question.id]?.trim());
}

function getStatusKey(
  detail: DailyReviewDetailData | null,
  isEditing: boolean,
  answers: AnswerMap,
  saving: boolean,
  isToday: boolean,
) {
  if (!detail) {
    return 'not_started';
  }
  if (saving) {
    return 'saving';
  }
  if (!detail.permissions.canView) {
    return 'no_permission';
  }
  if (detail.status === 'readonly') {
    return 'readonly';
  }
  if (detail.review.status === 'completed' && !isEditing) {
    return 'completed';
  }
  if (isEditing && hasAnswerContent(answers)) {
    return isToday ? 'filling' : 'backfilling';
  }
  return 'not_started';
}

function splitAnswerLines(content: string): string[] {
  return content
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function ReviewSummaryCards({
  detail,
  statusKey,
}: {
  detail: DailyReviewDetailData;
  statusKey: keyof typeof STATUS_CONFIG;
}) {
  const status = STATUS_CONFIG[statusKey];
  const cards = [
    {
      key: 'tasks',
      label: '今日任务',
      value: detail.summary.taskTotal,
      suffix: '项',
      icon: <FileDoneOutlined />,
      tone: 'blue',
    },
    {
      key: 'done',
      label: '已完成',
      value: detail.summary.completedCount,
      suffix: '项',
      icon: <CheckCircleFilled />,
      tone: 'green',
    },
    {
      key: 'undone',
      label: '未完成',
      value: detail.summary.uncompletedCount,
      suffix: '项',
      icon: <ClockCircleOutlined />,
      tone: 'orange',
    },
    {
      key: 'notes',
      label: '快速记录',
      value: detail.summary.quickNoteCount,
      suffix: '条',
      icon: <MessageOutlined />,
      tone: 'purple',
    },
  ];

  return (
    <section className="review-summary-strip" aria-label="复盘摘要">
      {cards.map((card) => (
        <article className={`review-summary-item is-${card.tone}`} key={card.key}>
          <span className="review-summary-icon">{card.icon}</span>
          <div>
            <span className="review-summary-label">{card.label}</span>
            <strong>
              {card.value}
              <small>{card.suffix}</small>
            </strong>
          </div>
        </article>
      ))}
      <article className={`review-summary-item is-status is-${status.tone}`}>
        <span className="review-summary-icon">
          <PieChartOutlined />
        </span>
        <div>
          <span className="review-summary-label">当前状态</span>
          <strong>{status.label}</strong>
        </div>
      </article>
    </section>
  );
}

function ReviewMaterialsPanel({ detail }: { detail: DailyReviewDetailData }) {
  const tasks = detail.materials.tasks;
  const quickNotes = detail.materials.quickNotes;
  const isEmpty = tasks.length === 0 && quickNotes.length === 0;

  return (
    <section className="review-panel review-material-panel">
      <div className="review-panel-header">
        <div>
          <h2>
            <CalendarOutlined />
            当天素材
          </h2>
          <p>可参考以下内容进行复盘</p>
        </div>
      </div>

      {isEmpty ? (
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="当天暂无任务或快速记录素材"
          className="review-material-empty"
        />
      ) : (
        <div className="review-material-groups">
          <section className="review-material-group">
            <div className="review-material-title">
              <span>
                <CheckCircleOutlined />
                当天任务
              </span>
              <Tag color="blue">{tasks.length}</Tag>
            </div>
            {tasks.length === 0 ? (
              <p className="review-material-muted">当天没有任务记录。</p>
            ) : (
              <div className="review-material-list">
                {tasks.map((task) => (
                  <ReviewTaskMaterial key={task.id} task={task} />
                ))}
              </div>
            )}
          </section>

          <section className="review-material-group">
            <div className="review-material-title">
              <span>
                <MessageOutlined />
                快速记录
              </span>
              <Tag color="geekblue">{quickNotes.length}</Tag>
            </div>
            {quickNotes.length === 0 ? (
              <p className="review-material-muted">当天没有快速记录。</p>
            ) : (
              <div className="review-note-material-list">
                {quickNotes.map((note) => (
                  <ReviewNoteMaterial key={note.id} note={note} />
                ))}
              </div>
            )}
          </section>
        </div>
      )}
    </section>
  );
}

function ReviewTaskMaterial({ task }: { task: Schedule }) {
  return (
    <article className={`review-task-material${task.completed ? ' is-completed' : ''}`}>
      <span className="review-task-check">
        {task.completed ? <CheckCircleFilled /> : <span />}
      </span>
      <div className="review-task-main">
        <strong>{task.title}</strong>
        <span>
          {task.startTime}-{task.endTime}
        </span>
      </div>
      <Tag color={task.category === '工作' ? 'blue' : 'green'}>{task.category}</Tag>
    </article>
  );
}

function ReviewNoteMaterial({ note }: { note: QuickNote }) {
  return (
    <article className="review-note-material">
      <time dateTime={note.createdAt}>{formatNoteTime(note)}</time>
      <p>{note.content}</p>
    </article>
  );
}

function createBlankSchemeQuestion(index: number): SchemeQuestionForm {
  return {
    clientId: `scheme-question-${Date.now()}-${index}`,
    title: '',
    placeholder: '请在此输入你的思考...',
    required: true,
    maxLength: 500,
  };
}

function toSchemeQuestionForm(scheme: ReviewQuestionScheme): SchemeQuestionForm[] {
  return scheme.questions
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((question) => ({
      clientId: question.id,
      id: question.id,
      title: question.title,
      placeholder: question.placeholder,
      required: question.required,
      maxLength: question.maxLength,
    }));
}

function buildSchemePayload(name: string, questions: SchemeQuestionForm[]) {
  const cleanName = name.trim();
  const cleanQuestions = questions
    .slice(0, MAX_SCHEME_QUESTIONS)
    .map((question) => ({
      id: question.id,
      title: question.title.trim(),
      placeholder: question.placeholder.trim(),
      required: question.required,
      maxLength: question.maxLength,
    }))
    .filter((question) => question.title);

  if (!cleanName || cleanQuestions.length === 0) {
    return null;
  }

  return { name: cleanName, questions: cleanQuestions };
}

function ReviewSchemeManagerModal({
  open,
  schemes,
  selectedSchemeId,
  saving,
  deletingId,
  onCancel,
  onUseScheme,
  onCreateScheme,
  onUpdateScheme,
  onDeleteScheme,
}: ReviewSchemeManagerModalProps) {
  const [editingId, setEditingId] = useState<string>('new');
  // 已保存的自定义方案默认只读，需点击「编辑」进入可编辑态
  const [isEditingExisting, setIsEditingExisting] = useState(false);
  const [schemeName, setSchemeName] = useState('');
  const [questions, setQuestions] = useState<SchemeQuestionForm[]>(() => [
    createBlankSchemeQuestion(1),
  ]);
  const activeScheme = schemes.find((scheme) => scheme.id === editingId);
  const isCreating = editingId === 'new';
  const isOfficial = Boolean(activeScheme?.source === 'official' && !isCreating);
  // 字段锁定：官方方案 / 已保存自定义方案未进入编辑态 / 保存中
  const isReadOnly = isOfficial || (!isCreating && !isEditingExisting);
  const payload = buildSchemePayload(schemeName, questions);
  // 可保存：有内容、非只读、非保存中
  const canSave = Boolean(payload) && !isReadOnly && !saving;

  const loadScheme = useCallback((scheme: ReviewQuestionScheme) => {
    setEditingId(scheme.id);
    setSchemeName(scheme.name);
    setQuestions(toSchemeQuestionForm(scheme));
    setIsEditingExisting(false);
  }, []);

  const startCreate = useCallback(() => {
    setEditingId('new');
    setIsEditingExisting(false);
    setSchemeName('我的复盘方案');
    setQuestions([
      {
        ...createBlankSchemeQuestion(1),
        title: '今天最值得记录的事情？',
        placeholder: '写下今天最值得被记住的一件事...',
      },
    ]);
  }, []);

  const cloneCurrentScheme = useCallback(() => {
    const source = activeScheme ?? schemes.find((scheme) => scheme.id === selectedSchemeId) ?? schemes[0];
    if (!source) {
      startCreate();
      return;
    }
    setEditingId('new');
    setIsEditingExisting(false);
    setSchemeName(`${source.name.replace(/ 副本$/, '')} 副本`);
    setQuestions(
      source.questions.map((question, index) => ({
        clientId: `scheme-question-copy-${Date.now()}-${index}`,
        title: question.title,
        placeholder: question.placeholder,
        required: question.required,
        maxLength: question.maxLength,
      })),
    );
  }, [activeScheme, schemes, selectedSchemeId, startCreate]);

  useEffect(() => {
    if (!open) {
      return;
    }
    const selected = schemes.find((scheme) => scheme.id === selectedSchemeId) ?? schemes[0];
    if (selected) {
      loadScheme(selected);
      return;
    }
    startCreate();
  }, [loadScheme, open, schemes, selectedSchemeId, startCreate]);

  const updateQuestion = useCallback(
    (clientId: string, patch: Partial<SchemeQuestionForm>) => {
      setQuestions((prev) =>
        prev.map((question) =>
          question.clientId === clientId ? { ...question, ...patch } : question,
        ),
      );
    },
    [],
  );

  const addQuestion = useCallback(() => {
    setQuestions((prev) =>
      prev.length >= MAX_SCHEME_QUESTIONS
        ? prev
        : [...prev, createBlankSchemeQuestion(prev.length + 1)],
    );
  }, []);

  const removeQuestion = useCallback((clientId: string) => {
    setQuestions((prev) =>
      prev.length <= 1 ? prev : prev.filter((question) => question.clientId !== clientId),
    );
  }, []);

  const handleSaveScheme = useCallback(async () => {
    const nextPayload = buildSchemePayload(schemeName, questions);
    if (!nextPayload) {
      message.warning('请填写方案名称和至少一个问题标题');
      return;
    }

    const saved = isCreating
      ? await onCreateScheme(nextPayload)
      : await onUpdateScheme({ id: editingId, ...nextPayload });
    if (!saved) {
      return;
    }

    if (isCreating) {
      // 新建：切到该方案的已保存只读态，并自动选为当前复盘方案，但不关闭弹窗
      setEditingId(saved.id);
      setIsEditingExisting(false);
      setSchemeName(saved.name);
      setQuestions(toSchemeQuestionForm(saved));
      onUseScheme(saved, { confirm: false });
    } else {
      // 编辑已有方案：保存后回到只读态，弹窗保持打开
      loadScheme(saved);
    }
  }, [editingId, isCreating, loadScheme, onCreateScheme, onUseScheme, onUpdateScheme, questions, schemeName]);

  // 进入编辑已有自定义方案
  const startEditExisting = useCallback(() => {
    setIsEditingExisting(true);
  }, []);

  // 取消编辑：回到只读态并恢复原始内容
  const cancelEditExisting = useCallback(() => {
    if (activeScheme) {
      setSchemeName(activeScheme.name);
      setQuestions(toSchemeQuestionForm(activeScheme));
    }
    setIsEditingExisting(false);
  }, [activeScheme]);

  const handleDeleteScheme = useCallback(() => {
    if (!activeScheme || activeScheme.source === 'official') {
      return;
    }

    Modal.confirm({
      title: '删除这个复盘方案？',
      icon: <ExclamationCircleFilled />,
      content: `「${activeScheme.name}」删除后无法恢复，已使用该方案的草稿会回到官方默认方案。`,
      okText: '删除',
      okButtonProps: { danger: true },
      cancelText: '取消',
      centered: true,
      onOk: async () => {
        const deleted = await onDeleteScheme(activeScheme.id);
        if (deleted) {
          const fallback = schemes.find((scheme) => scheme.isDefault) ?? schemes.find((scheme) => scheme.id !== activeScheme.id);
          if (fallback) {
            loadScheme(fallback);
          } else {
            startCreate();
          }
        }
      },
    });
  }, [activeScheme, loadScheme, onDeleteScheme, schemes, startCreate]);

  const handleUseScheme = useCallback(() => {
    const scheme = activeScheme ?? schemes.find((item) => item.id === editingId);
    if (!scheme) {
      message.info('请先保存当前自定义方案');
      return;
    }
    onUseScheme(scheme);
    onCancel();
  }, [activeScheme, editingId, onCancel, onUseScheme, schemes]);

  return (
    <Modal
      title={
        <div className="review-scheme-modal-title">
          <strong>管理复盘方案</strong>
          <span>官方方案可复制，自定义方案可新增、编辑和删除。</span>
        </div>
      }
      open={open}
      onCancel={onCancel}
      footer={[
        <Button key="cancel" onClick={onCancel}>
          关闭
        </Button>,
        <Button
          key="use"
          disabled={!activeScheme}
          onClick={handleUseScheme}
        >
          使用此方案
        </Button>,
        <Button
          key="save"
          type="primary"
          loading={saving}
          disabled={!canSave}
          onClick={() => void handleSaveScheme()}
        >
          保存方案
        </Button>,
      ]}
      width={900}
      centered
      className="review-scheme-modal"
    >
      <div className="review-scheme-manager">
        <aside className="review-scheme-list-panel">
          <div className="review-scheme-list-header">
            <span>方案列表</span>
            <Button
              size="small"
              className="review-scheme-new-button"
              icon={<PlusOutlined />}
              onClick={startCreate}
            >
              新建
            </Button>
          </div>
          <div className="review-scheme-list">
            {schemes.map((scheme) => {
              const isSelected = scheme.id === selectedSchemeId;
              const isEditing = scheme.id === editingId;
              return (
                <button
                  type="button"
                  key={scheme.id}
                  className={`review-scheme-list-item${isEditing ? ' is-active' : ''}${isSelected ? ' is-selected' : ''}`}
                  onClick={() => loadScheme(scheme)}
                >
                  <div className="review-scheme-list-item-head">
                    <strong>{scheme.name}</strong>
                    {isSelected && (
                      <CheckCircleFilled className="review-scheme-selected-mark" />
                    )}
                  </div>
                  <span>
                    {scheme.questions.length} 个问题
                    <Tag color={scheme.source === 'official' ? 'blue' : 'purple'}>
                      {scheme.source === 'official' ? '官方' : '自定义'}
                    </Tag>
                  </span>
                </button>
              );
            })}
          </div>
        </aside>

        <section className="review-scheme-editor">
          <div className="review-scheme-editor-header">
            <div>
              <h3>{isCreating ? '新建自定义方案' : schemeName}</h3>
              <p>
                {isOfficial
                  ? '官方方案不可修改，可点击「复制为自定义」后编辑。'
                  : isReadOnly
                    ? '已保存的自定义方案默认只读，点击「编辑」后可修改。'
                    : '最多设置 4 个问题，标题为空的问题不会被保存。'}
              </p>
            </div>
            <div className="review-scheme-editor-actions">
              {isOfficial && (
                <Button icon={<CopyOutlined />} onClick={cloneCurrentScheme}>
                  复制为自定义
                </Button>
              )}
              {!isCreating && !isOfficial && !isEditingExisting && (
                <>
                  <Button
                    danger
                    icon={<DeleteOutlined />}
                    loading={deletingId === editingId}
                    onClick={handleDeleteScheme}
                  >
                    删除
                  </Button>
                  <Button type="primary" icon={<EditOutlined />} onClick={startEditExisting}>
                    编辑
                  </Button>
                </>
              )}
              {!isCreating && !isOfficial && isEditingExisting && (
                <Button onClick={cancelEditExisting}>取消编辑</Button>
              )}
            </div>
          </div>

          <div className="review-scheme-form">
            <label className="review-scheme-field">
              <span>方案名称</span>
              <Input
                value={schemeName}
                maxLength={24}
                showCount
                disabled={isReadOnly || saving}
                placeholder="例如：我的晚间复盘"
                onChange={(event) => setSchemeName(event.target.value)}
              />
            </label>

            <div className="review-scheme-question-editor">
              <div className="review-scheme-question-editor-title">
                <span>复盘问题</span>
                <Button
                  size="small"
                  icon={<PlusOutlined />}
                  disabled={isReadOnly || questions.length >= MAX_SCHEME_QUESTIONS}
                  onClick={addQuestion}
                >
                  添加问题
                </Button>
              </div>

              <div className="review-scheme-question-list">
                {questions.map((question, index) => (
                  <article className="review-scheme-question-card" key={question.clientId}>
                    <div className="review-scheme-question-card-head">
                      <span>{index + 1}</span>
                      <Checkbox
                        checked={question.required}
                        disabled={isReadOnly || saving}
                        onChange={(event) =>
                          updateQuestion(question.clientId, { required: event.target.checked })
                        }
                      >
                        必填
                      </Checkbox>
                      <Button
                        type="text"
                        danger
                        size="small"
                        icon={<DeleteOutlined />}
                        disabled={isReadOnly || questions.length <= 1}
                        onClick={() => removeQuestion(question.clientId)}
                      />
                    </div>
                    <Input
                      value={question.title}
                      maxLength={32}
                      disabled={isReadOnly || saving}
                      placeholder="问题标题，例如：今天最大的收获是什么？"
                      onChange={(event) =>
                        updateQuestion(question.clientId, { title: event.target.value })
                      }
                    />
                    <Input.TextArea
                      value={question.placeholder}
                      maxLength={80}
                      disabled={isReadOnly || saving}
                      autoSize={{ minRows: 2, maxRows: 3 }}
                      placeholder="输入提示文案"
                      onChange={(event) =>
                        updateQuestion(question.clientId, { placeholder: event.target.value })
                      }
                    />
                  </article>
                ))}
              </div>
            </div>
          </div>
        </section>
      </div>
    </Modal>
  );
}

export function ReviewPage() {
  const { currentDate, setCurrentDate, goToToday } = useCurrentDate();
  const { openSettingsModal } = useSettingsModal();
  const {
    detail,
    schemes,
    status,
    error,
    saving,
    clearing,
    schemeSaving,
    schemeDeletingId,
    refetch,
    saveReview,
    clearReview,
    createScheme,
    updateScheme,
    deleteScheme,
  } = useDailyReview(currentDate);
  const {
    settings: markdownSettings,
    status: markdownSettingsStatus,
    hasSaveRoot,
  } = useMarkdownSettings();
  const {
    document: markdownDocument,
    status: markdownStatus,
    error: markdownError,
    generating: markdownGenerating,
    savingSource: markdownSavingSource,
    generateAndWrite,
    saveSource,
  } = useDailyMarkdown(currentDate);
  const { vaultRoot } = useVaultSync();
  const [settling, setSettling] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [selectedSchemeId, setSelectedSchemeId] = useState('');
  const [answers, setAnswers] = useState<AnswerMap>({});
  const [schemeManagerOpen, setSchemeManagerOpen] = useState(false);
  const [markdownModalOpen, setMarkdownModalOpen] = useState(false);
  const currentMonth = getMonthKey(currentDate);
  const isToday = currentDate === formatDate();

  // 迷你月历标记：扫描本地 Daily/*.md 派生（本地优先；复盘保存写文件后经 onFileChanged 自动刷新）
  const { monthData: calendarMonthData, loading: calendarLoading } =
    useLocalCalendarMonth(currentMonth);

  useEffect(() => {
    if (!detail) {
      setSelectedSchemeId('');
      setAnswers({});
      setIsEditing(false);
      return;
    }

    setSelectedSchemeId(detail.review.schemeId || detail.scheme.id);
    setAnswers(answersFromDetail(detail));
    setIsEditing(detail.review.status !== 'completed' && detail.permissions.canSave);
  }, [detail]);

  const selectedScheme = useMemo(() => {
    if (!detail && schemes.length === 0) {
      return undefined;
    }
    return schemes.find((scheme) => scheme.id === selectedSchemeId) ?? detail?.scheme ?? schemes[0];
  }, [detail, schemes, selectedSchemeId]);

  const answerHasContent = hasAnswerContent(answers);
  const requiredMissing = getRequiredMissing(selectedScheme, answers);
  const statusKey = getStatusKey(detail, isEditing, answers, saving, isToday);
  const isInitialLoading = status === 'loading' && !detail;
  const canEdit = Boolean(detail?.permissions.canEdit);
  const canSave = Boolean(detail?.permissions.canSave);
  const canSelectScheme = Boolean(detail?.permissions.canSelectScheme);
  const markdownSettingsLoading = markdownSettingsStatus === 'loading' && !markdownSettings;
  const markdownSaveBlocked = !hasSaveRoot || markdownSettingsLoading;
  const markdownSaveDisabledReason = markdownSettingsLoading
    ? '正在加载 Markdown 保存位置'
    : !hasSaveRoot
      ? '请先设置 Markdown 保存位置'
      : '';
  const markdownBusy = markdownGenerating || markdownSavingSource;
  const canViewMarkdown = Boolean(
    detail?.permissions.canView &&
      detail.status !== 'readonly' &&
      markdownDocument?.permissions.canView !== false &&
      markdownStatus !== 'error',
  );
  const noPermissionReason = detail?.permissions.reason ?? '暂无复盘操作权限';
  const pageTitle =
    !isToday && detail?.review.status !== 'completed' ? '补写复盘' : '今日复盘';

  const applySchemeSelection = useCallback(
    (nextScheme: ReviewQuestionScheme) => {
      setSelectedSchemeId(nextScheme.id);
      setAnswers((prev) => {
        const nextAnswers: AnswerMap = {};
        for (const question of nextScheme.questions) {
          if (prev[question.id]) {
            nextAnswers[question.id] = prev[question.id];
          }
        }
        return nextAnswers;
      });
    },
    [],
  );

  const handleSchemeChange = useCallback(
    (nextSchemeId: string) => {
      if (!canSelectScheme) {
        message.info(noPermissionReason);
        return;
      }
      if (nextSchemeId === selectedSchemeId) {
        return;
      }
      const nextScheme = schemes.find((scheme) => scheme.id === nextSchemeId);
      if (!nextScheme) {
        return;
      }
      if (answerHasContent) {
        Modal.confirm({
          title: '切换复盘方案？',
          icon: <ExclamationCircleFilled />,
          content: '切换后会按新方案的问题重新组织表单，无法匹配的问题内容将被清空。',
          okText: '切换',
          cancelText: '取消',
          centered: true,
          onOk: () => applySchemeSelection(nextScheme),
        });
        return;
      }
      applySchemeSelection(nextScheme);
    },
    [
      answerHasContent,
      applySchemeSelection,
      canSelectScheme,
      noPermissionReason,
      schemes,
      selectedSchemeId,
    ],
  );

  const handleUseManagedScheme = useCallback(
    (scheme: ReviewQuestionScheme, options: { confirm?: boolean } = {}) => {
      if (scheme.id === selectedSchemeId) {
        return;
      }
      if (!canSelectScheme) {
        message.info(noPermissionReason);
        return;
      }
      if (options.confirm === false || !answerHasContent) {
        applySchemeSelection(scheme);
        return;
      }
      Modal.confirm({
        title: '切换复盘方案？',
        icon: <ExclamationCircleFilled />,
        content: '切换后会按新方案的问题重新组织表单，无法匹配的问题内容将被清空。',
        okText: '切换',
        cancelText: '取消',
        centered: true,
        onOk: () => applySchemeSelection(scheme),
      });
    },
    [
      answerHasContent,
      applySchemeSelection,
      canSelectScheme,
      noPermissionReason,
      selectedSchemeId,
    ],
  );

  const handleDeleteManagedScheme = useCallback(
    async (id: string) => {
      const deleted = await deleteScheme(id);
      if (!deleted) {
        return false;
      }

      if (selectedSchemeId === id) {
        const fallback = schemes.find((scheme) => scheme.isDefault) ?? schemes.find((scheme) => scheme.id !== id);
        if (fallback) {
          setSelectedSchemeId(fallback.id);
          setAnswers((prev) => {
            const nextAnswers: AnswerMap = {};
            for (const question of fallback.questions) {
              if (prev[question.id]) {
                nextAnswers[question.id] = prev[question.id];
              }
            }
            return nextAnswers;
          });
        }
      }

      if (detail?.review.schemeId === id) {
        void refetch();
      }
      return true;
    },
    [deleteScheme, detail?.review.schemeId, refetch, schemes, selectedSchemeId],
  );

  const openUserSettings = useCallback(() => {
    openSettingsModal('space');
  }, [openSettingsModal]);

  const handleViewMarkdown = useCallback(async () => {
    if (!detail) {
      return;
    }
    if (!detail.permissions.canView) {
      message.info(detail.permissions.reason ?? '暂无查看权限');
      return;
    }
    if (detail.status === 'readonly') {
      message.info(detail.permissions.reason ?? '当前日期为只读演示场景');
      return;
    }
    if (!hasSaveRoot) {
      message.warning('请先设置 Markdown 保存位置');
      openUserSettings();
      return;
    }
    if (markdownStatus === 'error') {
      message.error(markdownError ?? 'Markdown 文档加载失败');
      return;
    }

    if (!markdownDocument?.content) {
      const generated = await generateAndWrite();
      if (!generated) {
        return;
      }
    }
    setMarkdownModalOpen(true);
  }, [
    detail,
    generateAndWrite,
    hasSaveRoot,
    markdownDocument?.content,
    markdownError,
    markdownStatus,
    openUserSettings,
  ]);

  /** 复盘沉淀：把当天结构化实体归档为零注释的 Notes/Daily/<date>.md（docs/09 §7.2）。 */
  const handleSettle = useCallback(async () => {
    if (!vaultRoot) {
      message.warning('请先设置 Markdown 保存位置');
      openSettingsModal();
      return;
    }
    setSettling(true);
    try {
      const result = await settleDay(vaultRoot, currentDate, { settledBy: 'manual' });
      if (result.status === 'empty') {
        message.info('当天没有可沉淀的内容');
      } else {
        message.success(
          result.overwritten
            ? `已重新沉淀到 ${settlementVaultPath(currentDate)}`
            : `已沉淀到 ${settlementVaultPath(currentDate)}`,
        );
      }
    } catch {
      message.error('沉淀失败，请稍后重试');
    } finally {
      setSettling(false);
    }
  }, [vaultRoot, currentDate, openSettingsModal]);

  const handleSave = useCallback(async () => {
    if (!detail || !selectedScheme) {
      return;
    }
    if (!canSave) {
      message.info(noPermissionReason);
      return;
    }
    if (markdownSaveBlocked) {
      message.warning(markdownSaveDisabledReason || '请先设置 Markdown 保存位置');
      openUserSettings();
      return;
    }
    if (requiredMissing) {
      message.warning('请先填写必填复盘问题');
      return;
    }

    const payloadAnswers: SaveDailyReviewAnswerPayload[] = selectedScheme.questions.map(
      (question) => ({
        questionId: question.id,
        content: answers[question.id]?.trim() ?? '',
      }),
    );

    const saved = await saveReview({
      date: currentDate,
      schemeId: selectedScheme.id,
      answers: payloadAnswers,
    });
    if (saved) {
      await generateAndWrite();
      setIsEditing(false);
    }
  }, [
    answers,
    canSave,
    currentDate,
    detail,
    generateAndWrite,
    markdownSaveBlocked,
    markdownSaveDisabledReason,
    noPermissionReason,
    openUserSettings,
    requiredMissing,
    saveReview,
    selectedScheme,
  ]);

  const handleClear = useCallback(() => {
    if (!detail) {
      return;
    }
    if (!detail.permissions.canClear) {
      message.info(noPermissionReason);
      return;
    }

    Modal.confirm({
      title: detail.review.status === 'completed' ? '清空已保存的复盘？' : '清空当前填写内容？',
      icon: <WarningOutlined />,
      content:
        detail.review.status === 'completed'
          ? '清空后该日期会回到未复盘状态，可继续重新填写。'
          : '当前表单内容会被清空。',
      okText: '确认清空',
      cancelText: '取消',
      centered: true,
      onOk: async () => {
        if (detail.review.status === 'completed') {
          const cleared = await clearReview();
          if (cleared) {
            setAnswers({});
            setIsEditing(true);
          }
          return;
        }
        setAnswers({});
      },
    });
  }, [clearReview, detail, noPermissionReason]);

  const handleEdit = useCallback(() => {
    if (!canEdit) {
      message.info(noPermissionReason);
      return;
    }
    setIsEditing(true);
  }, [canEdit, noPermissionReason]);

  const renderBanner = () => {
    if (status === 'error') {
      return (
        <Alert
          className="review-page-alert"
          type="error"
          showIcon
          title="复盘数据加载失败"
          description={error ?? '请检查网络或稍后重试。'}
          action={
            <Button size="small" icon={<ReloadOutlined />} onClick={() => void refetch()}>
              重试
            </Button>
          }
        />
      );
    }

    if (!detail) {
      return null;
    }

    if (!detail.permissions.canView) {
      return (
        <Alert
          className="review-page-alert"
          type="warning"
          showIcon
          title={detail.permissions.reason ?? '暂无查看该日期复盘的权限'}
        />
      );
    }

    if (detail.status === 'readonly') {
      return (
        <Alert
          className="review-page-alert"
          type="warning"
          showIcon
          title="当前日期为只读演示场景，可查看但不可修改复盘。"
        />
      );
    }

    if (!hasSaveRoot && (isEditing || detail.review.status === 'completed')) {
      return (
        <Alert
          className="review-page-alert"
          type="warning"
          showIcon
          title="请先设置 Markdown 保存位置"
          description="保存复盘时会生成并覆盖写入 Daily/YYYY-MM-DD.md，需要先指定本地保存根目录。"
          action={
            <Button size="small" onClick={openUserSettings}>
              设置保存位置
            </Button>
          }
        />
      );
    }

    if (detail.review.status === 'completed' && !isEditing) {
      return (
        <Alert
          className="review-page-alert"
          type="success"
          showIcon
          title={
            markdownDocument?.savedAt
              ? `今日复盘和 Markdown 文档已保存：${markdownDocument.relativePath}`
              : '今日复盘已保存，可查看或生成 Markdown 文档'
          }
        />
      );
    }

    if (!isToday) {
      return (
        <Alert
          className="review-page-alert"
          type="warning"
          showIcon
          title={`你尚未完成 ${formatDisplayDate(currentDate)} 的复盘，可根据当天记录补写。`}
        />
      );
    }

    return null;
  };

  const renderReviewPanel = () => {
    if (isInitialLoading) {
      return (
        <section className="review-panel review-loading-panel">
          <Spin />
          <span>正在加载复盘数据...</span>
        </section>
      );
    }

    if (!detail) {
      return (
        <section className="review-panel review-loading-panel">
          <Empty description="暂无复盘数据" />
        </section>
      );
    }

    if (!detail.permissions.canView) {
      return (
        <section className="review-panel review-loading-panel">
          <Empty description={detail.permissions.reason ?? '暂无查看权限'} />
        </section>
      );
    }

    return (
      <section className="review-panel review-question-panel">
        <div className="review-panel-header">
          <div>
            <h2>
              <PieChartOutlined />
              {isEditing ? '复盘问题' : '复盘内容'}
            </h2>
            <p>
              {isEditing
                ? '根据当前方案填写今天的复盘问题'
                : `使用「${selectedScheme?.name ?? '复盘方案'}」保存`}
            </p>
          </div>
          {!isEditing && (
            <Tooltip title={!canEdit ? noPermissionReason : ''}>
              <span>
                <Button
                  icon={<EditOutlined />}
                  disabled={!canEdit}
                  onClick={handleEdit}
                >
                  再次编辑
                </Button>
              </span>
            </Tooltip>
          )}
        </div>

        {isEditing && selectedScheme && (
          <div className="review-scheme-toolbar">
            <div className="review-scheme-select">
              <span>复盘方案</span>
              <Select
                value={selectedScheme.id}
                disabled={!canSelectScheme || saving}
                onChange={handleSchemeChange}
                options={schemes.map((scheme) => ({
                  value: scheme.id,
                  label: (
                    <span className="review-scheme-option">
                      {scheme.name}
                      <Tag color={scheme.source === 'official' ? 'blue' : 'purple'}>
                        {scheme.source === 'official' ? '官方' : '自定义'}
                      </Tag>
                    </span>
                  ),
                }))}
              />
            </div>
            <Button type="link" onClick={() => setSchemeManagerOpen(true)}>
              管理方案
            </Button>
          </div>
        )}

        {isEditing && !hasSaveRoot && (
          <Alert
            className="review-markdown-storage-alert"
            type="warning"
            showIcon
            message="保存复盘前，请先指定 Markdown 保存位置"
            description="保存后会自动生成并覆盖写入 Daily/YYYY-MM-DD.md。"
            action={
              <Button size="small" onClick={openUserSettings}>
                设置保存位置
              </Button>
            }
          />
        )}

        <div className="review-question-list">
          {selectedScheme?.questions.map((question, index) => (
            <article className="review-question-card" key={question.id}>
              <div className="review-question-heading">
                <span>{index + 1}</span>
                <strong>{question.title}</strong>
                {question.required && <Tag color="blue">必填</Tag>}
              </div>

              {isEditing ? (
                <div className="review-question-input-wrap">
                  <Input.TextArea
                    value={answers[question.id] ?? ''}
                    placeholder={question.placeholder}
                    maxLength={question.maxLength}
                    autoSize={{ minRows: 4, maxRows: 9 }}
                    disabled={!canSave || saving || markdownBusy}
                    className="review-question-input"
                    onChange={(event) =>
                      setAnswers((prev) => ({
                        ...prev,
                        [question.id]: event.target.value,
                      }))
                    }
                  />
                  <span className="review-question-count">
                    {(answers[question.id] ?? '').length} / {question.maxLength}
                  </span>
                </div>
              ) : (
                <div className="review-answer-content">
                  {splitAnswerLines(answers[question.id] ?? '').length > 0 ? (
                    splitAnswerLines(answers[question.id] ?? '').map((line) => (
                      <p key={line}>{line}</p>
                    ))
                  ) : (
                    <span>未填写</span>
                  )}
                </div>
              )}
            </article>
          ))}
        </div>

        <div className="review-actions">
          <span className="review-actions-tip">
            {isEditing
              ? hasSaveRoot
                ? `保存后会覆盖写入 ${markdownDocument?.relativePath ?? `Daily/${currentDate}.md`}`
                : '请先设置 Markdown 保存位置'
              : detail.review.completedAt
                ? markdownDocument?.savedAt
                  ? `Markdown 保存于 ${dayjs(markdownDocument.savedAt).format('HH:mm')}`
                  : `复盘保存于 ${dayjs(detail.review.completedAt).format('HH:mm')}`
                : '复盘已保存'}
          </span>
          <div>
            {!isToday && (
              <Button onClick={goToToday}>
                返回今天
              </Button>
            )}
            {isEditing ? (
              <>
                <Button
                  loading={clearing}
                  disabled={saving || markdownBusy || !answerHasContent}
                  onClick={handleClear}
                >
                  清空重写
                </Button>
                <Tooltip title={requiredMissing ? '请填写所有必填问题' : markdownSaveDisabledReason}>
                  <span>
                    <Button
                      type="primary"
                      className="review-save-button"
                      loading={saving || markdownGenerating}
                      disabled={!canSave || requiredMissing || markdownSaveBlocked}
                      onClick={() => void handleSave()}
                    >
                      保存复盘
                    </Button>
                  </span>
                </Tooltip>
              </>
            ) : (
              <>
                <Button onClick={handleEdit} disabled={!canEdit}>
                  再次编辑
                </Button>
                <Tooltip
                  title={
                    !canViewMarkdown
                      ? markdownError ?? detail.permissions.reason ?? '当前日期暂不可查看 Markdown'
                      : ''
                  }
                >
                  <span>
                    <Button
                      type="primary"
                      loading={markdownGenerating}
                      disabled={!canViewMarkdown}
                      onClick={() => void handleViewMarkdown()}
                    >
                      查看 Markdown
                    </Button>
                  </span>
                </Tooltip>
                <Tooltip title="把当天日程/快速记录/复盘/今日重点归档为零注释的干净 Markdown（Notes/Daily/），供 Obsidian 阅读与未来 AI 使用">
                  <span>
                    <Button
                      icon={<FileDoneOutlined />}
                      loading={settling}
                      disabled={!vaultRoot}
                      onClick={() => void handleSettle()}
                    >
                      复盘沉淀
                    </Button>
                  </span>
                </Tooltip>
              </>
            )}
          </div>
        </div>
      </section>
    );
  };

  return (
    <div className="review-page">
      <div className="review-page-header">
        <div>
          <h1 className="review-page-title">{pageTitle}</h1>
          <span className="review-page-date">
            {formatDisplayDate(currentDate)}　{formatShortWeekday(currentDate)}
          </span>
          <p className="review-page-desc">
            回顾今天的完成情况、沉淀收获，并明确明天最重要的一件事。
          </p>
        </div>
      </div>

      {renderBanner()}

      {detail && <ReviewSummaryCards detail={detail} statusKey={statusKey} />}

      <div className="review-workspace">
        <main className="review-main">
          {renderReviewPanel()}
          {detail && detail.permissions.canView && <ReviewMaterialsPanel detail={detail} />}
        </main>

        <aside className="review-page-right" aria-label="复盘侧边信息">
          <MiniCalendar
            monthData={calendarMonthData}
            loading={calendarLoading}
            onSelectDate={setCurrentDate}
          />
          <QuickNotes date={currentDate} />
        </aside>
      </div>

      <ReviewSchemeManagerModal
        open={schemeManagerOpen}
        schemes={schemes}
        selectedSchemeId={selectedSchemeId}
        saving={schemeSaving}
        deletingId={schemeDeletingId}
        onCancel={() => setSchemeManagerOpen(false)}
        onUseScheme={handleUseManagedScheme}
        onCreateScheme={createScheme}
        onUpdateScheme={updateScheme}
        onDeleteScheme={handleDeleteManagedScheme}
      />
      <DailyMarkdownModal
        open={markdownModalOpen}
        document={markdownDocument}
        loading={markdownStatus === 'loading'}
        saving={markdownSavingSource}
        error={markdownError}
        onClose={() => setMarkdownModalOpen(false)}
        onSaveSource={saveSource}
      />
    </div>
  );
}
