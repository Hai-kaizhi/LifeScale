import { useEffect, useState } from 'react';
import { getVaultEngineSingleton } from '../../services/vault';

/**
 * 本地优先文档编辑器 hook：内容来自本地 vault 文件；每次变更即时写本地并经同步引擎防抖上云。
 * 编辑器只关心本地内容，云端一致性由同步引擎在后台保证（push/pull/冲突）。
 */
export function useVaultDocumentEditor(vaultPath: string | null) {
  const engine = getVaultEngineSingleton();
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let alive = true;
    if (!vaultPath) {
      setContent('');
      return;
    }
    setLoading(true);
    void engine.readLocalFile(vaultPath).then((c) => {
      if (alive) {
        setContent(c);
        setLoading(false);
      }
    });
    return () => {
      alive = false;
    };
  }, [vaultPath, engine]);

  const onChange = (next: string) => {
    setContent(next);
    if (vaultPath) {
      void engine.onContentChange(vaultPath, next);
    }
  };

  return { content, onChange, loading };
}
