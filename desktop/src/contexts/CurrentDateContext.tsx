import { createContext, useContext, useState, useCallback, type ReactNode } from 'react';
import { formatDate } from '../shared/utils/date';

interface CurrentDateState {
  currentDate: string;
  setCurrentDate: (date: string) => void;
  goToToday: () => void;
}

const CurrentDateContext = createContext<CurrentDateState | null>(null);

export function CurrentDateProvider({ children }: { children: ReactNode }) {
  const [currentDate, setCurrentDate] = useState(() => formatDate());

  const goToToday = useCallback(() => {
    setCurrentDate(formatDate());
  }, []);

  return (
    <CurrentDateContext.Provider value={{ currentDate, setCurrentDate, goToToday }}>
      {children}
    </CurrentDateContext.Provider>
  );
}

export function useCurrentDate(): CurrentDateState {
  const ctx = useContext(CurrentDateContext);
  if (!ctx) throw new Error('useCurrentDate must be used within CurrentDateProvider');
  return ctx;
}
