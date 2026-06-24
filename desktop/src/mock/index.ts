/**
 * Mock switch — controlled via VITE_USE_MOCK env var.
 * Set VITE_USE_MOCK=true  to use mock data (default).
 * Set VITE_USE_MOCK=false to call real backend APIs.
 */
export const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false';
