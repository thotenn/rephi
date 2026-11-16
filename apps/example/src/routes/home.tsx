import { useAuthStore } from "@rephi/shared-components";
import Layout from "~/components/bedrock/Layout";
import NotificationSender from "~/components/NotificationSender";
import UserInfo from "~/components/UserInfo";
import { useRealtime } from "~/realtime/context";

export default function Home() {
  const user = useAuthStore((state) => state.user);
  const { connected } = useRealtime();

  return (
    <Layout>
      <UserInfo user={user} />

      <NotificationSender />

      <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">Welcome!</h2>
          <p className="text-gray-600">
            You have successfully logged into your Rephi account. This is your
            home dashboard where you can manage your account and access all the
            features of the application.
          </p>
          <p className="mt-4 text-sm text-gray-500" data-testid="realtime-hint">
            Live notifications: {connected ? "connected" : "not connected"}.
          </p>
        </div>
      </div>
    </Layout>
  );
}
