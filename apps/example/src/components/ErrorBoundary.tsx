import { Link } from "react-router";
import { ROUTE_PATHS } from "~/config/routes";

export default function ErrorBoundary() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-red-600 mb-4">Oops! Something went wrong</h1>
        <p className="text-gray-600">Please try refreshing the page or contact support if the problem persists.</p>
        <Link
          to={ROUTE_PATHS.home}
          reloadDocument
          className="mt-6 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
        >
          Go to the home page
        </Link>
      </div>
    </div>
  );
}
