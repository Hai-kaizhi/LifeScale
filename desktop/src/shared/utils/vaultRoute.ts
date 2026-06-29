import { ROUTES } from '../constants';
import type { VaultNodeKind } from '../types/vault';

export function buildVaultRoute(path: string | null, kind: VaultNodeKind = 'folder'): string {
  if (!path) {
    return ROUTES.VAULT;
  }
  const search = new URLSearchParams({
    path,
    kind,
  });
  return `${ROUTES.VAULT}?${search.toString()}`;
}
