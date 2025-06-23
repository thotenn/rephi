export function getCsrfToken(): string | null {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : null;
}

export function setCsrfHeader(headers: Record<string, string>): Record<string, string> {
  const token = getCsrfToken();
  if (token) {
    headers['x-csrf-token'] = token;
  }
  return headers;
}
