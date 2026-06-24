import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { SettingsCenterModal } from '../components/settings/SettingsCenterModal';

export type SettingsSection = 'profile' | 'sync' | 'space';

interface SettingsModalContextValue {
  openSettingsModal: (section?: SettingsSection) => void;
  closeSettingsModal: () => void;
}

const SettingsModalContext = createContext<SettingsModalContextValue | null>(null);

export function SettingsModalProvider({ children }: { children: ReactNode }) {
  const [modalState, setModalState] = useState<{ open: boolean; section: SettingsSection }>({
    open: false,
    section: 'profile',
  });

  const openSettingsModal = useCallback((section: SettingsSection = 'profile') => {
    setModalState({ open: true, section });
  }, []);

  const closeSettingsModal = useCallback(() => {
    setModalState((current) => ({ ...current, open: false }));
  }, []);

  const setActiveSection = useCallback((section: SettingsSection) => {
    setModalState((current) => ({ ...current, section }));
  }, []);

  const value = useMemo(
    () => ({ openSettingsModal, closeSettingsModal }),
    [closeSettingsModal, openSettingsModal],
  );

  return (
    <SettingsModalContext.Provider value={value}>
      {children}
      <SettingsCenterModal
        open={modalState.open}
        activeSection={modalState.section}
        onSectionChange={setActiveSection}
        onClose={closeSettingsModal}
      />
    </SettingsModalContext.Provider>
  );
}

export function useSettingsModal(): SettingsModalContextValue {
  const context = useContext(SettingsModalContext);
  if (!context) {
    throw new Error('useSettingsModal 必须在 SettingsModalProvider 内使用');
  }
  return context;
}
