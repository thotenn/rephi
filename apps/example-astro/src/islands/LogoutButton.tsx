import { logout } from "~/hooks/useAuth";

export default function LogoutButton() {
  return (
    <button
      type="button"
      onClick={logout}
      className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
    >
      Logout
    </button>
  );
}
