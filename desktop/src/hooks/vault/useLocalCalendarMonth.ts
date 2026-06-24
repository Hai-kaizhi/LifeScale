import { useCallback, useEffect, useState } from 'react';
import type { CalendarMonth } from '../../shared/types/calendar';
import { getVaultEngineSingleton } from '../../services/vault';
import { deriveCalendarMonthFromSettlements } from '../../services/vault/localCalendar';
import { listSettledDatesInMonth } from '../../services/vault/dailyEntities';
import { useVaultSync } from '../useVaultSync';

interface UseLocalCalendarMonthResult {
  monthData: CalendarMonth | undefined;
  loading: boolean;
}

/**
 * 迷你月历标记（docs/09 P3 settled 驱动）：查 ls_daily_settlement 有沉淀记录的日期，
 * 有记录 → 标记。性能好（单查 SQL），最符合「沉淀分层」语义。
 * 沉淀文件变化（Notes/Daily/）→ 重派生。
 */
export function useLocalCalendarMonth(month: string): UseLocalCalendarMonthResult {
  const engine = getVaultEngineSingleton();
  const { vaultRoot } = useVaultSync();

  const [monthData, setMonthData] = useState<CalendarMonth | undefined>(undefined);
  const [loading, setLoading] = useState(false);

  const derive = useCallback(async () => {
    if (!vaultRoot) {
      setMonthData(undefined);
      return;
    }
    setLoading(true);
    try {
      const data = await deriveCalendarMonthFromSettlements(month, {
        listSettledDates: (ym) => listSettledDatesInMonth(vaultRoot, ym),
      });
      setMonthData(data);
    } finally {
      setLoading(false);
    }
  }, [vaultRoot, month]);

  useEffect(() => {
    void derive();
  }, [derive]);

  // 沉淀文件变化（Notes/Daily/）→ 重派生
  useEffect(() => {
    const off = engine.onFileChanged((paths) => {
      if (paths.some((p) => p.startsWith('Notes/Daily/'))) void derive();
    });
    return off;
  }, [engine, derive]);

  return { monthData, loading };
}
