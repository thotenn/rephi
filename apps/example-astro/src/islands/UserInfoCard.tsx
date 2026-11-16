import { useAuthStore } from "~/lib/rephi";
import { roleBadgeClass } from "~/lib/roles";

interface UserInfoCardProps {
  /** Also list the effective permissions. */
  showPermissions?: boolean;
  className?: string;
}

/** Card with the signed-in user's details, read from the auth store. */
export default function UserInfoCard({ showPermissions = false, className = "" }: UserInfoCardProps) {
  const user = useAuthStore((state) => state.user);

  if (!user) {
    return null;
  }

  return (
    <div className={`bg-white overflow-hidden shadow rounded-lg ${className}`}>
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">
          User Information
        </h2>
        <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
          <div>
            <dt className="text-sm font-medium text-gray-500">Email</dt>
            <dd className="mt-1 text-sm text-gray-900">{user.email}</dd>
          </div>
          <div>
            <dt className="text-sm font-medium text-gray-500">User ID</dt>
            <dd className="mt-1 text-sm text-gray-900">{user.id}</dd>
          </div>
          <div>
            <dt className="text-sm font-medium text-gray-500">Roles</dt>
            <dd className="mt-1 flex flex-wrap gap-1" data-testid="user-roles">
              {user.roles.length > 0 ? (
                user.roles.map((role) => (
                  <span
                    key={role.id}
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${roleBadgeClass(role.slug)}`}
                  >
                    {role.name}
                  </span>
                ))
              ) : (
                <span className="text-sm text-gray-400">No roles</span>
              )}
            </dd>
          </div>
          <div>
            <dt className="text-sm font-medium text-gray-500">Permissions</dt>
            <dd className="mt-1 text-sm text-gray-900">
              {showPermissions && user.permissions.length > 0 ? (
                <span className="flex flex-wrap gap-1">
                  {user.permissions.map((permission) => (
                    <code
                      key={permission.id}
                      className="bg-gray-100 px-2 py-0.5 rounded text-xs text-gray-700"
                    >
                      {permission.slug}
                    </code>
                  ))}
                </span>
              ) : (
                user.permissions.length
              )}
            </dd>
          </div>
        </dl>
      </div>
    </div>
  );
}
