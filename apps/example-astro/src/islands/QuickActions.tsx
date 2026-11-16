import { usePermissions } from "~/lib/rephi";
import { ADMIN_PERMISSIONS, href, QUICK_LINKS, ROUTES } from "~/lib/routes";

interface QuickAction {
  label: string;
  url: string;
  permissions: readonly string[];
  icon: string;
}

const quickActions: QuickAction[] = [
  {
    label: "New role",
    url: QUICK_LINKS.newRole,
    permissions: [ADMIN_PERMISSIONS.roles, "roles:create"],
    icon: "M12 6v6m0 0v6m0-6h6m-6 0H6",
  },
  {
    label: "Send notification",
    url: QUICK_LINKS.sendNotification,
    permissions: ["notifications:broadcast"],
    icon: "M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9",
  },
  {
    label: "Manage users",
    url: href(ROUTES.admin.users),
    permissions: [ADMIN_PERMISSIONS.users],
    icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z",
  },
  {
    label: "My profile",
    url: href(ROUTES.pages.profile),
    permissions: [],
    icon: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z",
  },
];

export default function QuickActions() {
  const { canAll } = usePermissions();
  const visibleActions = quickActions.filter((action) => canAll(action.permissions));

  return (
    <nav aria-label="Quick actions" className="grid grid-cols-1 gap-4 sm:grid-cols-2">
      {visibleActions.map((action) => (
        <a
          key={action.label}
          href={action.url}
          className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          <svg
            aria-hidden="true"
            className="-ml-1 mr-2 h-5 w-5 text-gray-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={action.icon} />
          </svg>
          {action.label}
        </a>
      ))}
    </nav>
  );
}
