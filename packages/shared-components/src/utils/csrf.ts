/**
 * Utility functions for handling CSRF tokens
 */

/**
 * Get CSRF token from meta tag or window object
 * Phoenix injects the token in both places for flexibility
 */
export function getCSRFToken(): string | null {
  // First try to get from window object (fastest)
  if (typeof window !== 'undefined' && (window as any).__CSRF_TOKEN__) {
    return (window as any).__CSRF_TOKEN__;
  }

  // Fallback to meta tag
  if (typeof document !== 'undefined') {
    const metaTag = document.querySelector('meta[name="csrf-token"]');
    if (metaTag) {
      return metaTag.getAttribute('content');
    }
  }

  return null;
}

/**
 * Add CSRF token to request headers
 */
export function addCSRFHeader(headers: Record<string, string> = {}): Record<string, string> {
  const token = getCSRFToken();
  
  if (token) {
    return {
      ...headers,
      'x-csrf-token': token,
    };
  }
  
  return headers;
}