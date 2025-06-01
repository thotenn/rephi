import { Link, useLocation } from "react-router-dom";
import { useLogout } from "~/hooks/useAuth";
import { urls } from "~/env";

interface HeaderProps {
  title?: string;
}

export default function Header({ title = "Welcome to Rephi" }: HeaderProps) {
  const logout = useLogout();
  const location = useLocation();

  const isActive = (path: string) => location.pathname === path;

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
