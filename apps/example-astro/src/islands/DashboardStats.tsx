import { useQuery } from "@tanstack/react-query";
import IslandProviders from "~/components/react/IslandProviders";
import { dashboardKey } from "~/lib/api/dashboard";
import { useOnlineCounts } from "~/lib/realtime";
import { fetchDashboard, usePermissions } from "~/lib/rephi";

interface TileProps {
  id: string;
  label: string;
  value: number | null | undefined;
  detail?: string;
  icon: string;
}

function Tile({ id, label, value, detail, icon }: TileProps) {
  return (
    <div className="bg-white overflow-hidden shadow rounded-lg" data-testid={`tile-${id}`}>
      <div className="p-5">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            <svg aria-hidden="true" className="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={icon} />
            </svg>
          </div>
          <div className="ml-5 w-0 flex-1">
            <dl>
              <dt className="text-sm font-medium text-gray-500 truncate">{label}</dt>
              <dd className="text-lg font-medium text-gray-900" data-testid={`tile-${id}-value`}>
                {value ?? "—"}
              </dd>
              {detail && (
                <dd className="text-xs text-gray-500" data-testid={`tile-${id}-detail`}>
                  {detail}
                </dd>
              )}
            </dl>
          </div>
        </div>
      </div>
    </div>
  );
}

const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? "" : "s"}`;

function Stats() {
  const { can } = usePermissions();
  const online = useOnlineCounts();
  const { data } = useQuery({ queryKey: dashboardKey, queryFn: fetchDashboard, staleTime: 0 });
  const showUsers = data ? data.users.total !== null : can("users:view");
  const showAllNotifications = data
    ? data.notifications.sent_total !== null
    : can("notifications:broadcast");
  const sessions = online ?? data?.sessions;

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {showUsers && (
        <Tile
          id="users"
          label="Total Users"
          value={data?.users.total}
          icon="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
        />
      )}
      <Tile
        id="notifications"
        label={showAllNotifications ? "Notifications Sent" : "Notifications You Sent"}
        value={showAllNotifications ? data?.notifications.sent_total : data?.notifications.sent_by_me}
        detail={showAllNotifications && data ? `${data.notifications.sent_by_me} by you` : undefined}
        icon="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
      />
      <Tile
        id="sessions"
        label="Active Sessions"
        value={sessions?.online_users}
        detail={sessions ? plural(sessions.connections, "connection") : undefined}
        icon="M13 10V3L4 14h7v7l9-11h-7z"
      />
    </div>
  );
}

export default function DashboardStats() {
  return (
    <IslandProviders>
      <Stats />
    </IslandProviders>
  );
}
