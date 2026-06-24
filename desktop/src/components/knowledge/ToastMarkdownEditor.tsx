import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef } from 'react';
import type { MouseEvent } from 'react';
import { Crepe, CrepeFeature } from '@milkdown/crepe';
import { useEditor, Milkdown, MilkdownProvider } from '@milkdown/react';
import { $prose } from '@milkdown/kit/utils';
import { replaceAll } from '@milkdown/kit/utils';
import { editorViewCtx } from '@milkdown/kit/core';
import type { EditorProps } from '@milkdown/kit/prose/view';
import { Plugin, PluginKey } from '@milkdown/kit/prose/state';
import {
  search,
  SearchQuery,
  setSearchState,
  getMatchHighlights,
  findNext as pmFindNext,
  findPrev as pmFindPrev,
} from 'prosemirror-search';
import '@milkdown/crepe/theme/common/style.css';
import '@milkdown/crepe/theme/frame.css';
import { getVaultEngineSingleton } from '../../services/vault';
import { atomicWriteFileBytes, sha256HexBytes } from '../../services/vault/vaultFileBridge';
import { useVaultSync } from '../../hooks/useVaultSync';
import './ToastMarkdownEditor.css';

/** 附件相对引用：attachments/<hash>.<ext>。 */
const ATTACHMENT_SRC_RE = /^attachments\/([0-9a-f]{64})\.(\w+)$/;

const CREPE_FEATURE_CONFIGS = {
  [CrepeFeature.Placeholder]: {
    text: '输入 “/” 选择',
    mode: 'block',
  },
  [CrepeFeature.BlockEdit]: {
    textGroup: {
      label: '文本',
      text: { label: '正文' },
      h1: { label: '一级标题' },
      h2: { label: '二级标题' },
      h3: { label: '三级标题' },
      h4: { label: '四级标题' },
      h5: { label: '五级标题' },
      h6: { label: '六级标题' },
      quote: { label: '引用' },
      divider: { label: '分割线' },
    },
    listGroup: {
      label: '列表',
      bulletList: { label: '无序列表' },
      orderedList: { label: '有序列表' },
      taskList: { label: '待办列表' },
    },
    advancedGroup: {
      label: '高级',
      image: { label: '图片' },
      codeBlock: { label: '代码块' },
      table: { label: '表格' },
      math: { label: '公式' },
    },
  },
  [CrepeFeature.CodeMirror]: {
    searchPlaceholder: '搜索语言',
    noResultText: '未找到结果',
  },
} as const;

function extFromMime(mime: string): string {
  if (mime === 'image/png') return 'png';
  if (mime === 'image/jpeg') return 'jpg';
  if (mime === 'image/gif') return 'gif';
  if (mime === 'image/webp') return 'webp';
  if (mime === 'image/svg+xml') return 'svg';
  return 'png';
}

async function readImageBytes(file: File): Promise<Uint8Array> {
  const buf = await file.arrayBuffer();
  return new Uint8Array(buf);
}

/** 从粘贴事件/拖拽事件里提取图片 File 列表。返回空数组表示非图片操作（不接管）。 */
function collectImageFiles(clipboardData: DataTransfer | null): File[] {
  if (!clipboardData) return [];
  const files: File[] = [];
  for (const item of Array.from(clipboardData.items)) {
    if (item.type.startsWith('image/')) {
      const file = item.getAsFile();
      if (file) files.push(file);
    }
  }
  return files;
}

/**
 * Markdown 编辑器（基于 Milkdown Crepe，WYSIWYG 渲染态可编辑）。
 *
 * 设计要点：
 * - **默认渲染态可编辑**：Milkdown 灵感来自 Typora，输入 `# `/`- `/`> ` 等会自动渲染为
 *   对应块（标题/列表/引用），符合 Obsidian / Notion 的所见即所得体验，无需源码/预览分屏。
 * - **搜索（Ctrl+F）由 ProseMirror 官方 `prosemirror-search` 驱动**：通过 Milkdown 的 `$prose`
 *   把 search() 插件注入编辑器。匹配高亮由 Decoration 直接渲染在内容 DOM 上
 *   （类名 `ProseMirror-search-match` / `ProseMirror-active-search-match`），基于文档字符
 *   偏移定位，不存在任何坐标换算，因此不会出现「overlay 覆盖层」方案在嵌套滚动/重排时的偏移。
 * - **图片粘贴/拖入由 ProseMirror `handlePaste`/`handleDrop` 插件 props 统一接管**：
 *   返回 true 短路 ProseMirror 原生 doPaste（避免「原生用剪贴板 HTML 插一张 + 自定义用 files
 *   再插一张」导致的双图 bug），确保一张图片只产生一个 `attachments/<hash>.<ext>` 引用。
 * - 保持与旧版编辑器相同的对外 props 契约（value / readOnly / height / onChange），
 *   其中 previewStyle / initialEditType 仅做兼容性吸收（WYSIWYG 模式下不再区分）。
 * - 通过 ref 暴露搜索能力（focus / setSearchKeyword / findNext / findPrev / clearSearch / getMatchCount）。
 */
export interface ToastMarkdownEditorProps {
  value: string;
  readOnly?: boolean;
  height?: string;
  /** 兼容旧契约，WYSIWYG 模式下统一为渲染态编辑，此参数不再区分。 */
  previewStyle?: 'vertical' | 'tab';
  /** 兼容旧契约，WYSIWYG 模式下统一为渲染态编辑，此参数不再区分。 */
  initialEditType?: 'markdown' | 'wysiwyg';
  onChange?: (value: string) => void;
}

export interface ToastMarkdownEditorHandle {
  /** 聚焦编辑器。 */
  focus: () => void;
  /** 设置搜索关键词（同时设置大小写），更新高亮。空字符串清除高亮。 */
  setSearchKeyword: (keyword: string, caseSensitive: boolean) => void;
  /** 跳到下一个匹配（ProseMirror 官方命令）。 */
  findNext: () => void;
  /** 跳到上一个匹配（ProseMirror 官方命令）。 */
  findPrev: () => void;
  /** 清除搜索状态（关闭高亮）。 */
  clearSearch: () => void;
  /** 获取当前匹配数量（基于高亮装饰集）。 */
  getMatchCount: () => number;
}

// 用 $prose 把 prosemirror-search 的 search() 插件包装成 Milkdown 插件。
// search() 内部维护 SearchQuery 与高亮 DecorationSet，由外层通过 setSearchState 驱动。
const searchPlugin = $prose(() => search());

/** 处理图片插入的稳定回调签名（用于把外层闭包注入 ProseMirror 插件）。 */
type AttachmentInserter = (files: File[]) => void;

/**
 * 创建一个带 handlePaste/handleDrop 的 ProseMirror 插件，统一接管图片粘贴/拖入。
 * 关键：命中图片时返回 true，短路 ProseMirror 原生 doPaste/drop（否则会再用剪贴板 HTML
 * 插一次图，造成「一张图变两张」）。getInserter 在每次事件触发时实时取最新 ref，
 * 保证 vaultRoot/engine 等闭包始终是最新值。
 */
function createAttachmentPastePlugin(getInserter: () => AttachmentInserter) {
  return $prose(() => {
    // 用 EditorProps 显式标注，让 handlePaste/handleDrop 的形参类型由 ProseMirror 推断，
    // 避免手写 Slice 等跨包类型。命中图片返回 true 短路原生 doPaste/drop（杜绝双图）。
    const props: EditorProps = {
      handlePaste: (view, event) => {
        const files = collectImageFiles(event.clipboardData);
        if (!files.length) return false; // 非图片：交还原生处理（文本/表格等）
        event.preventDefault();
        void view; // 插入由 inserter 内部经 crepeRef 发起，这里不直接用 view
        getInserter()(files);
        return true; // 短路原生 doPaste
      },
      handleDrop: (view, event) => {
        const files = collectImageFiles(event.dataTransfer);
        if (!files.length) return false; // 非图片文件：交还原生
        event.preventDefault();
        void view;
        getInserter()(files);
        return true;
      },
    };
    return new Plugin({
      key: new PluginKey('lifescale-attachment-paste'),
      props,
    });
  });
}

interface CrepeEditorProps {
  value: string;
  readOnly: boolean;
  onChange: (markdown: string) => void;
  onCrepeReady: (crepe: Crepe) => void;
  /** 注入附件图片粘贴插件（getInserter 实时取最新插入器）。 */
  getInserter: () => AttachmentInserter;
}

/**
 * 内部编辑器：在 MilkdownProvider 内运行，通过 useEditor 注册 Crepe 工厂并渲染 <Milkdown />。
 * useEditor 的回调接收 <Milkdown> 渲染出的根 div 作为容器，返回 Crepe 实例后，
 * <Milkdown> 会自动调用 .create() 挂载、卸载时调用 .destroy()。
 */
function CrepeEditor({ value, readOnly, onChange, onCrepeReady, getInserter }: CrepeEditorProps) {
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  useEditor(
    (root) => {
      const crepe = new Crepe({
        root,
        defaultValue: value,
        // TopBar 默认即为关闭（opt-in），这里显式列出保持意图清晰；其余默认功能
        // （slash 命令、Typora 式输入规则、表格、链接 tooltip、占位符、列表、光标等）全部开启。
        features: {},
        featureConfigs: CREPE_FEATURE_CONFIGS,
      });

      // 注入搜索插件（prosemirror-search），开启匹配高亮。
      crepe.editor.use(searchPlugin);
      // 注入图片粘贴/拖入插件：返回 true 短路原生 doPaste，避免双图。
      crepe.editor.use(createAttachmentPastePlugin(getInserter));

      // 监听 Markdown 变化，回写上层。markdownUpdated 在内容变化时（debounce 200ms）触发。
      crepe.on((listener) => {
        listener.markdownUpdated((_ctx, markdown) => {
          onChangeRef.current(markdown);
        });
      });

      crepe.setReadonly(readOnly);

      // 同步 crepe 实例给外层（用 queueMicrotask 确保在 create 完成后）。
      queueMicrotask(() => onCrepeReady(crepe));

      return crepe;
    },
    [],
  );

  return <Milkdown />;
}

export const ToastMarkdownEditor = forwardRef<ToastMarkdownEditorHandle, ToastMarkdownEditorProps>(
  function ToastMarkdownEditor({ value, readOnly = false, height = '640px', onChange }, ref) {
    const crepeRef = useRef<Crepe | null>(null);
    // 记录最近一次来自外部的 value，用于判断受控写入是否真的需要执行，
    // 避免编辑器回写 → setState → value 回流时重复写入导致光标跳动。
    const lastExternalValueRef = useRef<string>(value);

    const handleCrepeReady = (crepe: Crepe) => {
      crepeRef.current = crepe;
    };

    const handleChange = (markdown: string) => {
      // 记录回写的值，使下方受控 effect 跳过这次回流的写入。
      lastExternalValueRef.current = markdown;
      onChange?.(markdown);
    };

    // 受控 value 同步：仅在外部 value 与「最近一次写入/回写的值」不一致时更新。
    useEffect(() => {
      const crepe = crepeRef.current;
      if (!crepe) {
        return;
      }
      if (value !== lastExternalValueRef.current) {
        const current = crepe.getMarkdown();
        if (current !== value) {
          crepe.editor.action(replaceAll(value));
        }
        lastExternalValueRef.current = value;
      }
    }, [value]);

    // 只读状态变化时同步。
    useEffect(() => {
      crepeRef.current?.setReadonly(readOnly);
    }, [readOnly]);

    // ---- 附件（图片）：粘贴/拖入 → 内容寻址 → 本地缓存 + 入队上传 + 插入相对引用；WYSIWYG 内联显图 ----
    const { vaultRoot } = useVaultSync();
    const engine = getVaultEngineSingleton();
    const shellRef = useRef<HTMLDivElement | null>(null);
    const blobUrls = useRef<Map<string, string>>(new Map()); // hash → blob URL（会话内缓存）

    /** 把 <img src="attachments/hash.ext"> 解析为本地缓存的 blob URL 并替换显示 src。
     *  仅改 DOM 显示；ProseMirror 文档/src 仍为相对引用 → getMarkdown 输出可移植。 */
    const resolveAttachmentImg = useCallback(
      async (img: HTMLImageElement) => {
        const src = img.getAttribute('src') ?? '';
        const m = src.match(ATTACHMENT_SRC_RE);
        if (!m) return;
        const [, hash, ext] = m;
        if (img.dataset.attHash === hash) return; // 已解析（blob 或占位）
        img.dataset.attHash = hash;
        let blobUrl = blobUrls.current.get(hash);
        if (!blobUrl) {
          const bytes = await engine.readAttachmentBytes(hash, ext);
          if (!bytes) {
            // 本地缓存缺失：占位 + 后台懒拉取（联网后 onAttachmentAvailable 触发重扫描）
            img.style.background = '#f1f5f9';
            img.alt = '图片加载中…';
            void engine.ensureAttachment(hash, ext);
            return;
          }
          blobUrl = URL.createObjectURL(new Blob([bytes]));
          blobUrls.current.set(hash, blobUrl);
        }
        img.src = blobUrl;
      },
      [engine],
    );

    const scanImgs = useCallback(() => {
      const root = shellRef.current;
      if (!root) return;
      root.querySelectorAll<HTMLImageElement>('img').forEach((img) => {
        if (ATTACHMENT_SRC_RE.test(img.getAttribute('src') ?? '')) void resolveAttachmentImg(img);
      });
    }, [resolveAttachmentImg]);

    // 编辑器就绪后：扫描附件 img → blob；MutationObserver 持续解析新增/重渲染的 img；订阅附件可用事件刷新。
    useEffect(() => {
      const root = shellRef.current;
      if (!root) return;
      scanImgs();
      const observer = new MutationObserver(() => scanImgs());
      observer.observe(root, { subtree: true, childList: true, attributes: true, attributeFilter: ['src'] });
      const off = engine.onAttachmentAvailable(() => scanImgs());
      return () => {
        observer.disconnect();
        off();
      };
    }, [engine, scanImgs]);

    // 卸载释放 blob URL。
    useEffect(() => {
      const cache = blobUrls.current;
      return () => {
        cache.forEach((url) => URL.revokeObjectURL(url));
        cache.clear();
      };
    }, []);

    const insertAttachment = useCallback(
      async (file: File) => {
        if (!vaultRoot) return;
        const bytes = await readImageBytes(file);
        const hash = await sha256HexBytes(bytes);
        const ext = extFromMime(file.type);
        const rel = `attachments/${hash}.${ext}`;
        await atomicWriteFileBytes(vaultRoot, rel, bytes);
        engine.enqueueAttachmentUpload(hash, ext);
        crepeRef.current?.editor.action((ctx) => {
          const view = ctx.get(editorViewCtx);
          const imageType = view.state.schema.nodes.image;
          if (!imageType) return;
          const tr = view.state.tr.replaceSelectionWith(
            imageType.create({ src: rel, alt: file.name || 'image' }),
          );
          view.dispatch(tr);
          view.focus();
        });
      },
      [vaultRoot, engine],
    );

    /**
     * 批量插入图片。用 ref 包装，保证传给 ProseMirror 插件的 getInserter 始终取到最新闭包
     * （vaultRoot/engine/crepeRef 变化时不需重建插件）。由 handlePaste/handleDrop 插件调用。
     */
    const insertFilesRef = useRef<AttachmentInserter>((files) => {
      for (const file of files) void insertAttachment(file);
    });
    insertFilesRef.current = (files) => {
      for (const file of files) void insertAttachment(file);
    };
    const getInserter = useCallback(() => insertFilesRef.current, []);

    // 暴露搜索与聚焦能力。
    useImperativeHandle(
      ref,
      () => ({
        focus: () => {
          crepeRef.current?.editor.action((ctx) => {
            ctx.get(editorViewCtx).focus();
          });
        },
        setSearchKeyword: (keyword: string, caseSensitive: boolean) => {
          crepeRef.current?.editor.action((ctx) => {
            const view = ctx.get(editorViewCtx);
            const query = new SearchQuery({ search: keyword, caseSensitive });
            const tr = view.state.tr;
            setSearchState(tr, query);
            view.dispatch(tr);
          });
        },
        findNext: () => {
          crepeRef.current?.editor.action((ctx) => {
            const view = ctx.get(editorViewCtx);
            pmFindNext(view.state, view.dispatch.bind(view));
            view.focus();
          });
        },
        findPrev: () => {
          crepeRef.current?.editor.action((ctx) => {
            const view = ctx.get(editorViewCtx);
            pmFindPrev(view.state, view.dispatch.bind(view));
            view.focus();
          });
        },
        clearSearch: () => {
          crepeRef.current?.editor.action((ctx) => {
            const view = ctx.get(editorViewCtx);
            const tr = view.state.tr;
            setSearchState(tr, new SearchQuery({ search: '' }));
            view.dispatch(tr);
          });
        },
        getMatchCount: () => {
          const crepe = crepeRef.current;
          if (!crepe) return 0;
          return crepe.editor.action((ctx) => {
            const view = ctx.get(editorViewCtx);
            return getMatchHighlights(view.state).find().length;
          });
        },
      }),
      [],
    );

    return (
      <div
        ref={shellRef}
        className="knowledge-milkdown-shell"
        style={{ height }}
        onMouseDown={(event: MouseEvent<HTMLDivElement>) => {
          if (event.target === event.currentTarget) {
            crepeRef.current?.editor.action((ctx) => {
              ctx.get(editorViewCtx).focus();
            });
          }
        }}
      >
        <MilkdownProvider>
          <CrepeEditor
            value={value}
            readOnly={readOnly}
            onChange={handleChange}
            onCrepeReady={handleCrepeReady}
            getInserter={getInserter}
          />
        </MilkdownProvider>
      </div>
    );
  },
);

export default ToastMarkdownEditor;
