import { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { urls } from "~/env";
import { useLogout } from "~/hooks/useAuth";
import { useAuthStore } from "@rephi/shared-components";
import { isAdmin } from "~/utils/auth";

interface HeaderProps {
  title?: string;
}

export default function Header({ title = "Welcome to Rephi" }: HeaderProps) {
  const logout = useLogout();
  const location = useLocation();
  const { user } = useAuthStore();
  const [showAdminDropdown, setShowAdminDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const isActive = (path: string) => location.pathname === path;
  const userIsAdmin = isAdmin(user);

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
            <nav className="flex space-x-4">
              <Link
                to={urls.home}
                className={`px-3 py-2 rounded-md text-sm font-medium ${
                  isActive(urls.home)
                    ? "bg-gray-900 text-white"
                    : "text-gray-700 hover:bg-gray-700 hover:text-white"
                }`}
              >
                Home
              </Link>
              <Link
                to={urls.pages.dashboard}
                className={`px-3 py-2 rounded-md text-sm font-medium ${
                  isActive(urls.pages.dashboard)
                    ? "bg-gray-900 text-white"
                    : "text-gray-700 hover:bg-gray-700 hover:text-white"
                }`}
              >
                Dashboard
              </Link>
              <Link
                to={urls.pages.profile}
                className={`px-3 py-2 rounded-md text-sm font-medium ${
                  isActive(urls.pages.profile)
                    ? "bg-gray-900 text-white"
                    : "text-gray-700 hover:bg-gray-700 hover:text-white"
                }`}
              >
                Profile
              </Link>
              
              {/* Admin Menu */}
              {userIsAdmin && (
                <div className="relative" ref={dropdownRef}>
                  <button
                    onClick={() => setShowAdminDropdown(!showAdminDropdown)}
                    className={`px-3 py-2 rounded-md text-sm font-medium flex items-center ${
                      location.pathname.startsWith("/admin")
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
                        <Link
                          to="/admin/users"
                          onClick={() => setShowAdminDropdown(false)}
                          className={`block px-4 py-2 text-sm ${
                            isActive("/admin/users")
                              ? "bg-gray-100 text-gray-900"
                              : "text-gray-700 hover:bg-gray-100"
                          }`}
                        >
                          User Management
                        </Link>
                        <Link
                          to="/admin/roles"
                          onClick={() => setShowAdminDropdown(false)}
                          className={`block px-4 py-2 text-sm ${
                            isActive("/admin/roles")
                              ? "bg-gray-100 text-gray-900"
                              : "text-gray-700 hover:bg-gray-100"
                          }`}
                        >
                          Roles Management
                        </Link>
                        <Link
                          to="/admin/permissions"
                          onClick={() => setShowAdminDropdown(false)}
                          className={`block px-4 py-2 text-sm ${
                            isActive("/admin/permissions")
                              ? "bg-gray-100 text-gray-900"
                              : "text-gray-700 hover:bg-gray-100"
                          }`}
                        >
                          Permissions Management
                        </Link>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </nav>
          </div>
          <button
            onClick={logout}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Logout
          </button>
        </div>
      </div>
    </header>
  );
}
