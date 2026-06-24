package com.lifescale.backend.vault.service;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * 行级三方合并（diff3）：base / ours / theirs → 合并文本，并标注是否冲突。
 * <p>
 * 标准做法：分别对 base↔ours、base↔theirs 求 LCS 得到两套变更 hunk（每个 hunk = 一段 base 区间被替换为若干行）。
 * 然后沿 base 推进：仅一侧变更 → 取该侧；两侧变更的 base 区间 <b>重叠</b> 才冲突（同点插入亦视为重叠），
 * 否则各自独立应用。这样「A 改第1行、B 改第2行」这类不相邻锚点但独立的改动能干净合并。
 * 冲突块以 git 风格 &lt;&lt;&lt;&lt;&lt;&lt;&lt; / ======= / &gt;&gt;&gt;&gt;&gt;&gt;&gt; 标记输出。
 */
public final class ThreeWayMerge {

    public static final class Result {
        public final boolean clean;
        public final String text;

        public Result(boolean clean, String text) {
            this.clean = clean;
            this.text = text;
        }
    }

    /** 一段变更：base[bStart..bEnd) 被替换为 lines（可为空 = 纯删除；bStart==bEnd = 纯插入）。 */
    private static final class Hunk {
        final int bStart;
        final int bEnd;
        final List<String> lines;

        Hunk(int bStart, int bEnd, List<String> lines) {
            this.bStart = bStart;
            this.bEnd = bEnd;
            this.lines = lines;
        }
    }

    private ThreeWayMerge() {
    }

    public static Result merge(String base, String ours, String theirs) {
        String[] b = split(base);
        String[] o = split(ours);
        String[] t = split(theirs);
        List<Hunk> hunksA = diffHunks(b, match(b, o), o);
        List<Hunk> hunksB = diffHunks(b, match(b, t), t);

        List<String> out = new ArrayList<>();
        boolean conflict = false;
        int p = 0;
        int ia = 0;
        int ib = 0;
        while (ia < hunksA.size() || ib < hunksB.size()) {
            Hunk ha = ia < hunksA.size() ? hunksA.get(ia) : null;
            Hunk hb = ib < hunksB.size() ? hunksB.get(ib) : null;

            if (ha == null) {
                copy(out, b, p, hb.bStart);
                out.addAll(hb.lines);
                p = hb.bEnd;
                ib++;
                continue;
            }
            if (hb == null) {
                copy(out, b, p, ha.bStart);
                out.addAll(ha.lines);
                p = ha.bEnd;
                ia++;
                continue;
            }

            if (!overlap(ha, hb)) {
                // 不重叠：先处理起始位置更早的一侧
                if (ha.bStart <= hb.bStart) {
                    copy(out, b, p, ha.bStart);
                    out.addAll(ha.lines);
                    p = ha.bEnd;
                    ia++;
                } else {
                    copy(out, b, p, hb.bStart);
                    out.addAll(hb.lines);
                    p = hb.bEnd;
                    ib++;
                }
                continue;
            }

            // 重叠 → 合并区段，向两侧扩张吸收所有链式重叠的 hunk
            int iaStart = ia;
            int ibStart = ib;
            int cs = Math.min(ha.bStart, hb.bStart);
            int ce = Math.max(ha.bEnd, hb.bEnd);
            ia++;
            ib++;
            boolean grew = true;
            while (grew) {
                grew = false;
                while (ia < hunksA.size() && hunksA.get(ia).bStart < ce) {
                    ce = Math.max(ce, hunksA.get(ia).bEnd);
                    ia++;
                    grew = true;
                }
                while (ib < hunksB.size() && hunksB.get(ib).bStart < ce) {
                    ce = Math.max(ce, hunksB.get(ib).bEnd);
                    ib++;
                    grew = true;
                }
            }
            copy(out, b, p, cs);
            List<String> aSeg = reconstruct(b, hunksA.subList(iaStart, ia), cs, ce);
            List<String> bSeg = reconstruct(b, hunksB.subList(ibStart, ib), cs, ce);
            if (aSeg.equals(bSeg)) {
                out.addAll(aSeg);
            } else {
                conflict = true;
                out.add("<<<<<<< mine");
                out.addAll(aSeg);
                out.add("=======");
                out.addAll(bSeg);
                out.add(">>>>>>> theirs");
            }
            p = ce;
        }
        copy(out, b, p, b.length);
        return new Result(!conflict, String.join("\n", out));
    }

    /** 两侧 base 区间是否重叠（同点插入 bStart 相等也视为重叠）。 */
    private static boolean overlap(Hunk a, Hunk c) {
        return a.bStart == c.bStart || (a.bStart < c.bEnd && c.bStart < a.bEnd);
    }

    /** 用被吸收的 hunk + 区间内未变更(匹配)的 base 行，重建该侧在 [from,to) 的内容。 */
    private static List<String> reconstruct(String[] base, List<Hunk> consumed, int from, int to) {
        List<String> out = new ArrayList<>();
        int i = from;
        int h = 0;
        while (i < to) {
            if (h < consumed.size() && consumed.get(h).bStart == i) {
                out.addAll(consumed.get(h).lines);
                i = consumed.get(h).bEnd;
                h++;
            } else {
                out.add(base[i]);
                i++;
            }
        }
        return out;
    }

    private static void copy(List<String> out, String[] b, int from, int to) {
        for (int i = from; i < to; i++) {
            out.add(b[i]);
        }
    }

    /** 由 base 与 X 的 LCS 匹配，产出 X 相对 base 的变更 hunk 列表（按 bStart 升序）。 */
    private static List<Hunk> diffHunks(String[] base, int[] xForBase, String[] x) {
        List<Hunk> hunks = new ArrayList<>();
        int prevB = -1;
        int prevX = -1;
        for (int bi = 0; bi < base.length; bi++) {
            if (xForBase[bi] != -1) {
                int bStart = prevB + 1;
                int bEnd = bi;
                int xStart = prevX + 1;
                int xEnd = xForBase[bi];
                if (bStart < bEnd || xStart < xEnd) {
                    hunks.add(new Hunk(bStart, bEnd, slice(x, xStart, xEnd)));
                }
                prevB = bi;
                prevX = xForBase[bi];
            }
        }
        int bStart = prevB + 1;
        int bEnd = base.length;
        int xStart = prevX + 1;
        int xEnd = x.length;
        if (bStart < bEnd || xStart < xEnd) {
            hunks.add(new Hunk(bStart, bEnd, slice(x, xStart, xEnd)));
        }
        return hunks;
    }

    private static List<String> slice(String[] arr, int from, int to) {
        List<String> l = new ArrayList<>(Math.max(0, to - from));
        for (int i = from; i < to; i++) {
            l.add(arr[i]);
        }
        return l;
    }

    private static String[] split(String s) {
        if (s == null || s.isEmpty()) {
            return new String[0];
        }
        return s.split("\n", -1);
    }

    /** 对 base 每一行，返回在 x 中的 LCS 匹配下标（单调递增），未匹配为 -1。 */
    private static int[] match(String[] base, String[] x) {
        int n = base.length;
        int m = x.length;
        int[] result = new int[n];
        Arrays.fill(result, -1);
        if (n == 0 || m == 0) {
            return result;
        }
        int[][] dp = new int[n + 1][m + 1];
        for (int i = n - 1; i >= 0; i--) {
            for (int j = m - 1; j >= 0; j--) {
                dp[i][j] = base[i].equals(x[j]) ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
            }
        }
        int i = 0;
        int j = 0;
        while (i < n && j < m) {
            if (base[i].equals(x[j])) {
                result[i] = j;
                i++;
                j++;
            } else if (dp[i + 1][j] >= dp[i][j + 1]) {
                i++;
            } else {
                j++;
            }
        }
        return result;
    }
}
