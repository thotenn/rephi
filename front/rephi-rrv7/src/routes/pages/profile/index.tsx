import { useAuthStore } from "~/stores/auth.store";
import Layout from "~/components/Layout";

export default function Profile() {
  const { user } = useAuthStore();

  if (!user) {
    return null;
  }

  return (
    <Layout title="User Profile">
      <div className="bg-white overflow-hidden shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-6">User Information</h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-sm font-medium text-gray-500">Email Address</h3>
              <p className="mt-1 text-sm text-gray-900">{user.email}</p>
            </div>

            <div>
              <h3 className="text-sm font-medium text-gray-500">User ID</h3>
              <p className="mt-1 text-sm text-gray-900">{user.id}</p>
            </div>

            {user.created_at && (
              <div>
                <h3 className="text-sm font-medium text-gray-500">Member Since</h3>
                <p className="mt-1 text-sm text-gray-900">
                  {new Date(user.created_at).toLocaleDateString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </p>
              </div>
            )}

            {user.updated_at && (
              <div>
                <h3 className="text-sm font-medium text-gray-500">Last Updated</h3>
                <p className="mt-1 text-sm text-gray-900">
                  {new Date(user.updated_at).toLocaleDateString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">Account Settings</h2>
          <p className="text-gray-600">
            Account settings and preferences will be available here in future updates.
          </p>
        </div>
      </div>
    </Layout>
  );
}