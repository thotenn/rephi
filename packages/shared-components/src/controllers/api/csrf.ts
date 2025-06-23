export function getCsrfToken(): string | null {
  // First try to get from window object (fastest)
  if (typeof window !== 'undefined' && (window as any).__CSRF_TOKEN__) {
    return (window as any).__CSRF_TOKEN__;
  }

  // Fallback to meta tag
  if (typeof document !== 'undefined') {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : null;
  }

  return null;
}

export function setCsrfHeader(headers: Record<string, string>): Record<string, string> {
  const token = getCsrfToken();
  if (token) {
    headers['x-csrf-token'] = token;
  }
  return headers;
}
