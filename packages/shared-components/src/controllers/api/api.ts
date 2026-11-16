import axios, { AxiosHeaders, isAxiosError } from "axios";
import { getRephiConfig, onRephiConfigChange } from "../../config";
import { toApiError } from "../../errors";
import { endSession, isSigningOut } from "../../session";
import { useAuthStore } from "../../stores/auth.store";

const api = axios.create({
  baseURL: getRephiConfig().apiUrl,
});

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

    // A late 401 for a token replaced since (re-login) must not end the new session.
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
