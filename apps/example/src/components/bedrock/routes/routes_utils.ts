const REDIRECT_KEY = "auth_redirect_path";

export function setRedirectPath(path: string) {
  if (process.env.NODE_ENV === "development") {
    console.log("Setting redirect path:", path);
  }
  sessionStorage.setItem(REDIRECT_KEY, path);
}

export function getRedirectPath(): string | null {
  const path = sessionStorage.getItem(REDIRECT_KEY);
  if (process.env.NODE_ENV === "development") {
    console.log("Getting redirect path:", path);
  }
  return path;
}

export function clearRedirectPath(): void {
  if (process.env.NODE_ENV === "development") {
    console.log("Clearing redirect path");
  }
  sessionStorage.removeItem(REDIRECT_KEY);
}