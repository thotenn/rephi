import { useState } from "react";
import { signOut } from "~/hooks/useAuth";

export default function LogoutButton() {
  const [pending, setPending] = useState(false);

  const handleClick = () => {
    setPending(true);
    // The session always ends locally, whatever the server answered.
    void signOut().finally(() => setPending(false));
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={pending}
      className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
    >
      {pending ? "Signing out..." : "Logout"}
    </button>
  );
}
