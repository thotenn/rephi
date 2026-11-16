import { useAuthStore } from "~/lib/rephi";

interface UserInfoCardProps {
  showUpdatedAt?: boolean;
  className?: string;
}

const formatDate = (value: string) =>
  new Date(value).toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });

/** Card with the signed-in user's details, read from the auth store. */
export default function UserInfoCard({ showUpdatedAt = false, className = "" }: UserInfoCardProps) {
  const user = useAuthStore((state) => state.user);

  if (!user) {
    return null;
  }

  // The API names the creation timestamp `inserted_at` (Ecto's default).
  const memberSince = user.inserted_at;

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
          {memberSince && (
            <div>
              <dt className="text-sm font-medium text-gray-500">
                Member Since
              </dt>
              <dd className="mt-1 text-sm text-gray-900">
                {formatDate(memberSince)}
              </dd>
            </div>
          )}
          {showUpdatedAt && user.updated_at && (
            <div>
              <dt className="text-sm font-medium text-gray-500">
                Last Updated
              </dt>
              <dd className="mt-1 text-sm text-gray-900">
                {formatDate(user.updated_at)}
              </dd>
            </div>
          )}
        </dl>
      </div>
    </div>
  );
}
