import { useEffect, useRef, useState } from "react";
import { isAdmin } from "~/lib/auth";
import { useAuthStore } from "~/lib/rephi";
import { href, isRoute, isUnderRoute, ROUTES } from "~/lib/routes";

interface AdminMenuProps {
  /** Pathname of the page being rendered, provided by Astro at build time. */
  pathname: string;
}

const links = [
  { route: ROUTES.admin.users, label: "User Management" },
  { route: ROUTES.admin.roles, label: "Roles Management" },
  { route: ROUTES.admin.permissions, label: "Permissions Management" },
];

/** Admin dropdown of the header. Renders nothing for non-admin users. */
export default function AdminMenu({ pathname }: AdminMenuProps) {
  const user = useAuthStore((state) => state.user);
  const [showAdminDropdown, setShowAdminDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowAdminDropdown(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  if (!isAdmin(user)) return null;

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        type="button"
        onClick={() => setShowAdminDropdown(!showAdminDropdown)}
        aria-haspopup="true"
        aria-expanded={showAdminDropdown}
        className={`px-3 py-2 rounded-md text-sm font-medium flex items-center ${
          isUnderRoute(pathname, ROUTES.admin.root)
            ? "bg-red-600 text-white"
            : "text-gray-700 hover:bg-red-600 hover:text-white"
        }`}
      >
        Admin
        <svg
          className="ml-1 h-4 w-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      {showAdminDropdown && (
        <div className="absolute left-0 mt-2 w-48 bg-white rounded-md shadow-lg ring-1 ring-black ring-opacity-5 z-50">
          <div className="py-1">
            {links.map((link) => (
              <a
                key={link.route}
                href={href(link.route)}
                onClick={() => setShowAdminDropdown(false)}
                className={`block px-4 py-2 text-sm ${
                  isRoute(pathname, link.route)
                    ? "bg-gray-100 text-gray-900"
                    : "text-gray-700 hover:bg-gray-100"
                }`}
              >
                {link.label}
              </a>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
