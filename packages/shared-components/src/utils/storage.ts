/**
 * Returns the requested Web Storage area, or `null` when it is not available:
 * during server-side rendering / prerendering, or in browsers that block storage
 * access (reading the property can throw a `SecurityError` there).
 */
export function getStorage(kind: 'local' | 'session'): Storage | null {
  try {
    if (typeof window === 'undefined') return null;
    return kind === 'local' ? window.localStorage : window.sessionStorage;
  } catch {
    return null;
  }
}
