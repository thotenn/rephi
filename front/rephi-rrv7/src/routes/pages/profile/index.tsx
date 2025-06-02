import { useAuthStore } from "~/stores/auth.store";
import Layout from "~/components/bedrock/Layout";
import UserInfo from "~/components/UserInfo";

export default function Profile() {
  const { user } = useAuthStore();

  return (
    <Layout title="User Profile">
      <UserInfo user={user} showUpdatedAt={true} />

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