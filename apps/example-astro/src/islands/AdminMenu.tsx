import { useEffect, useRef, useState } from "react";
import { usePermissions } from "~/lib/rephi";
import { ADMIN_PERMISSIONS, href, isRoute, isUnderRoute, ROUTES } from "~/lib/routes";

interface AdminMenuProps {
  pathname: string;
}

const links = [
  { route: ROUTES.admin.users, label: "User Management", permission: ADMIN_PERMISSIONS.users },
  { route: ROUTES.admin.roles, label: "Roles Management", permission: ADMIN_PERMISSIONS.roles },
  {
    route: ROUTES.admin.permissions,
    label: "Permissions Management",
    permission: ADMIN_PERMISSIONS.permissions,
  },
];

export default function AdminMenu({ pathname }: AdminMenuProps) {
  const { can } = usePermissions();
  const visibleLinks = links.filter((link) => can(link.permission));
  const [showAdminDropdown, setShowAdminDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

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

  if (visibleLinks.length === 0) return null;

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
            {visibleLinks.map((link) => (
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
