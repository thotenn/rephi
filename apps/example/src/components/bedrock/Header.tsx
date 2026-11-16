import { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router";
import { usePermissions } from "@rephi/shared-components";
import { ADMIN_PERMISSIONS, ROUTE_PATHS } from "~/config/routes";
import { useLogout } from "~/hooks/useAuth";

const adminLinks = [
  { to: ROUTE_PATHS.admin.users, label: "User Management", permission: ADMIN_PERMISSIONS.users },
  { to: ROUTE_PATHS.admin.roles, label: "Roles Management", permission: ADMIN_PERMISSIONS.roles },
  {
    to: ROUTE_PATHS.admin.permissions,
    label: "Permissions Management",
    permission: ADMIN_PERMISSIONS.permissions,
  },
];

const mainLinks = [
  { to: ROUTE_PATHS.home, label: "Home" },
  { to: ROUTE_PATHS.pages.dashboard, label: "Dashboard" },
  { to: ROUTE_PATHS.pages.profile, label: "Profile" },
];

interface HeaderProps {
  title?: string;
}

export default function Header({ title = "Welcome to Rephi" }: HeaderProps) {
  const logout = useLogout();
  const location = useLocation();
  const { can } = usePermissions();
  const [showAdminDropdown, setShowAdminDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const isActive = (path: string) => location.pathname === path;
  const visibleAdminLinks = adminLinks.filter((link) => can(link.permission));

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowAdminDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  return (
    <header className="bg-white shadow">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center py-6">
          <div className="flex items-center space-x-8">
            <h1 className="text-3xl font-bold text-gray-900">{title}</h1>
            <nav className="flex space-x-4" aria-label="Main">
              {mainLinks.map((link) => (
                <Link
                  key={link.to}
                  to={link.to}
                  aria-current={isActive(link.to) ? "page" : undefined}
                  className={`px-3 py-2 rounded-md text-sm font-medium ${
                    isActive(link.to)
                      ? "bg-gray-900 text-white"
                      : "text-gray-700 hover:bg-gray-700 hover:text-white"
                  }`}
                >
                  {link.label}
                </Link>
              ))}

              {/* Admin Menu */}
              {visibleAdminLinks.length > 0 && (
                <div className="relative" ref={dropdownRef}>
                  <button
                    type="button"
                    onClick={() => setShowAdminDropdown(!showAdminDropdown)}
                    aria-haspopup="true"
                    aria-expanded={showAdminDropdown}
                    className={`px-3 py-2 rounded-md text-sm font-medium flex items-center ${
                      location.pathname.startsWith(ROUTE_PATHS.admin.root)
                        ? "bg-red-600 text-white"
                        : "text-gray-700 hover:bg-red-600 hover:text-white"
                    }`}
                  >
                    Admin
                    <svg
                      aria-hidden="true"
                      className="ml-1 h-4 w-4" 
                      fill="none" 
                      stroke="currentColor" 
                      viewBox="0 0 24 24"
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
                        {visibleAdminLinks.map((link) => (
                          <Link
                            key={link.to}
                            to={link.to}
                            onClick={() => setShowAdminDropdown(false)}
                            className={`block px-4 py-2 text-sm ${
                              isActive(link.to)
                                ? "bg-gray-100 text-gray-900"
                                : "text-gray-700 hover:bg-gray-100"
                            }`}
                          >
                            {link.label}
                          </Link>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}
            </nav>
          </div>
          <button
            type="button"
            onClick={() => logout.mutate()}
            disabled={logout.isPending}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            {logout.isPending ? "Signing out..." : "Logout"}
          </button>
        </div>
      </div>
    </header>
  );
}
