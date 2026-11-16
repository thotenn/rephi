import axios, { AxiosHeaders, isAxiosError } from "axios";
import { getRephiConfig, onRephiConfigChange } from "../../config";
import { toApiError } from "../../errors";
import { endSession, isSigningOut } from "../../session";
import { useAuthStore } from "../../stores/auth.store";

/**
 * The axios instance every request to the API goes through.
 *
 * - Sends the session token as `Authorization: Bearer <token>`.
 * - Rejects with an `ApiError` (see `errors.ts`) built from the error envelope.
 * - A 401 on a request that carried the current token ends the session
 *   (`endSession("unauthorized")`): the token expired or was revoked.
 */
const api = axios.create({
  baseURL: getRephiConfig().apiUrl,
});

// Follow `configureRephi({ apiUrl })` calls made after this module was loaded.
onRephiConfigChange(({ apiUrl }) => {
  api.defaults.baseURL = apiUrl;
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token && !config.headers.has("Authorization")) {
    config.headers.set("Authorization", `Bearer ${token}`);
  }
  return config;
});

function bearerOf(headers: unknown): string | null {
  const value = AxiosHeaders.from(headers as AxiosHeaders).get("Authorization");
  return typeof value === "string" && value.startsWith("Bearer ") ? value.slice(7) : null;
}

api.interceptors.response.use(
  (response) => response,
  (error: unknown) => {
    if (!isAxiosError(error)) return Promise.reject(error);
    if (axios.isCancel(error)) return Promise.reject(error);

    const response = error.response;

    // Only a token that is still the current one ends the session: a late
    // answer to a request sent before a re-login must not sign the user out.
    if (response?.status === 401) {
      const sentToken = bearerOf(error.config?.headers);
      if (sentToken && sentToken === useAuthStore.getState().token && !isSigningOut()) {
        endSession("unauthorized");
      }
    }

    return Promise.reject(toApiError(response, error));
  }
);

export default api;
