import { ADMIN, API_URL, api, cleanup } from "./support/api";

// Shared by read-only tests: none may sign out, which revokes every token of the user.
export default async function globalSetup() {
  try {
    await fetch(`${API_URL}/health`);
  } catch {
    throw new Error(`The API does not answer at ${API_URL}. Start it, or set E2E_API_URL (see the README).`);
  }

  const admin = await api.login(ADMIN.email, ADMIN.password);
  const plain = await api.registerUnique("e2e-plain");

  process.env.E2E_ADMIN_SESSION = JSON.stringify(admin);
  process.env.E2E_PLAIN_SESSION = JSON.stringify(plain);

  return () => cleanup(() => api.deleteUser(admin.token, plain.user.id));
}
