/**
 * 行级三方合并（diff3）—— 后端 ThreeWayMerge 的前端镜像，供冲突 UI 的「合并预览」使用。
 * 算法：分别求 base↔ours、base↔theirs 的 LCS 变更 hunk；沿 base 推进，仅一侧变更取该侧，
 * 两侧变更的 base 区间重叠才冲突。这样独立的相邻改动能干净合并。
 */
export interface MergeResult {
  clean: boolean;
  text: string;
}

interface Hunk {
  bStart: number;
  bEnd: number;
  lines: string[];
}

function split(s: string): string[] {
  if (!s) return [];
  return s.split('\n');
}

/** base 每行在 x 中的 LCS 匹配下标，未匹配 -1。 */
function match(base: string[], x: string[]): number[] {
  const n = base.length;
  const m = x.length;
  const result = new Array<number>(n).fill(-1);
  if (n === 0 || m === 0) return result;
  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array<number>(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = base[i] === x[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (base[i] === x[j]) {
      result[i] = j;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) i++;
    else j++;
  }
  return result;
}

function diffHunks(base: string[], xForBase: number[], x: string[]): Hunk[] {
  const hunks: Hunk[] = [];
  let prevB = -1;
  let prevX = -1;
  for (let bi = 0; bi < base.length; bi++) {
    if (xForBase[bi] !== -1) {
      const bStart = prevB + 1;
      const bEnd = bi;
      const xStart = prevX + 1;
      const xEnd = xForBase[bi];
      if (bStart < bEnd || xStart < xEnd) hunks.push({ bStart, bEnd, lines: x.slice(xStart, xEnd) });
      prevB = bi;
      prevX = xForBase[bi];
    }
  }
  const bStart = prevB + 1;
  const bEnd = base.length;
  const xStart = prevX + 1;
  const xEnd = x.length;
  if (bStart < bEnd || xStart < xEnd) hunks.push({ bStart, bEnd, lines: x.slice(xStart, xEnd) });
  return hunks;
}

function overlap(a: Hunk, c: Hunk): boolean {
  return a.bStart === c.bStart || (a.bStart < c.bEnd && c.bStart < a.bEnd);
}

function reconstruct(base: string[], consumed: Hunk[], from: number, to: number): string[] {
  const out: string[] = [];
  let i = from;
  let h = 0;
  while (i < to) {
    if (h < consumed.length && consumed[h].bStart === i) {
      out.push(...consumed[h].lines);
      i = consumed[h].bEnd;
      h++;
    } else {
      out.push(base[i]);
      i++;
    }
  }
  return out;
}

export function threeWayMerge(base: string, ours: string, theirs: string): MergeResult {
  const b = split(base);
  const o = split(ours);
  const t = split(theirs);
  const hunksA = diffHunks(b, match(b, o), o);
  const hunksB = diffHunks(b, match(b, t), t);

  const out: string[] = [];
  let conflict = false;
  let p = 0;
  let ia = 0;
  let ib = 0;
  while (ia < hunksA.length || ib < hunksB.length) {
    const ha = ia < hunksA.length ? hunksA[ia] : null;
    const hb = ib < hunksB.length ? hunksB[ib] : null;

    if (!ha && hb) {
      out.push(...b.slice(p, hb.bStart), ...hb.lines);
      p = hb.bEnd;
      ib++;
      continue;
    }
    if (!hb && ha) {
      out.push(...b.slice(p, ha.bStart), ...ha.lines);
      p = ha.bEnd;
      ia++;
      continue;
    }
    if (ha && hb && !overlap(ha, hb)) {
      if (ha.bStart <= hb.bStart) {
        out.push(...b.slice(p, ha.bStart), ...ha.lines);
        p = ha.bEnd;
        ia++;
      } else {
        out.push(...b.slice(p, hb.bStart), ...hb.lines);
        p = hb.bEnd;
        ib++;
      }
      continue;
    }
    if (ha && hb) {
      // 重叠 → 扩张合并区段
      const iaStart = ia;
      const ibStart = ib;
      let cs = Math.min(ha.bStart, hb.bStart);
      let ce = Math.max(ha.bEnd, hb.bEnd);
      ia++;
      ib++;
      let grew = true;
      while (grew) {
        grew = false;
        while (ia < hunksA.length && hunksA[ia].bStart < ce) {
          ce = Math.max(ce, hunksA[ia].bEnd);
          ia++;
          grew = true;
        }
        while (ib < hunksB.length && hunksB[ib].bStart < ce) {
          ce = Math.max(ce, hunksB[ib].bEnd);
          ib++;
          grew = true;
        }
      }
      out.push(...b.slice(p, cs));
      const aSeg = reconstruct(b, hunksA.slice(iaStart, ia), cs, ce);
      const bSeg = reconstruct(b, hunksB.slice(ibStart, ib), cs, ce);
      if (arrEq(aSeg, bSeg)) {
        out.push(...aSeg);
      } else {
        conflict = true;
        out.push('<<<<<<< mine', ...aSeg, '=======', ...bSeg, '>>>>>>> theirs');
      }
      p = ce;
    }
  }
  out.push(...b.slice(p, b.length));
  return { clean: !conflict, text: out.join('\n') };
}

function arrEq(a: string[], c: string[]): boolean {
  if (a.length !== c.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== c[i]) return false;
  return true;
}
