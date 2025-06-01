import { useNavigate } from "@remix-run/react";
import { useEffect, useState } from "react";
import { useAuthStore } from "~/stores/auth.store";
import { useChannel } from "~/hooks/useChannel";
import { useLogout } from "~/hooks/useAuth";
import toast, { Toaster } from "react-hot-toast";
import api from "~/modules/api/api";
import PhoenixSocket from "~/modules/api/socket";
import { apisUrl, channelsProps, urls } from "~/env";

export default function Home() {
  const navigate = useNavigate();
  const { user, token } = useAuthStore();
  const logout = useLogout();
  const [notificationText, setNotificationText] = useState("");
  const [sending, setSending] = useState(false);
  const { channel, connected } = useChannel(channelsProps.topics.user.lobby);

  useEffect(() => {
    if (!token) {
      navigate(urls.auth.login);
    } else {
      // Connect socket when user is authenticated
      PhoenixSocket.connect();
    }
    
    return () => {
      // Disconnect on unmount
      PhoenixSocket.disconnect();
    };
  }, [token, navigate]);

  useEffect(() => {
    if (channel && connected) {
      const ref = channel.on(channelsProps.events.user.notification, (payload) => {
        toast.success(payload.message, {
          duration: 5000,
          position: "top-right",
          icon: "🔔",
        });
      });

      return () => {
        channel.off(channelsProps.events.user.notification, ref);
      };
    }
  }, [channel, connected]);

  const handleLogout = () => {
    logout();
  };

  const handleSendNotification = async () => {
    if (!notificationText.trim()) {
      toast.error("Please enter a notification message");
      return;
    }

    setSending(true);
    try {
      await api.post(apisUrl.sockets.notifications, {
        message: notificationText,
      });
      setNotificationText("");
      toast.success("Notification sent!");
    } catch (error) {
      toast.error("Failed to send notification");
    } finally {
      setSending(false);
    }
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster />
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-3xl font-bold text-gray-900">Welcome to Rephi</h1>
            <button
              onClick={handleLogout}
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">User Information</h2>
              <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                <div>
                  <dt className="text-sm font-medium text-gray-500">Email</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user.email}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">User ID</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user.id}</dd>
                </div>
                {user.created_at && (
                  <div>
                    <dt className="text-sm font-medium text-gray-500">Member Since</dt>
                    <dd className="mt-1 text-sm text-gray-900">
                      {new Date(user.created_at).toLocaleDateString()}
                    </dd>
                  </div>
                )}
              </dl>
            </div>
          </div>

          <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Send Notification</h2>
              <p className="text-gray-600 mb-4">
                Send a notification to all connected users
              </p>
              <div className="mb-4">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                  connected ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                }`}>
                  {connected ? '🟢 Connected' : '🔴 Disconnected'}
                </span>
              </div>
              <div className="flex space-x-3">
                <input
                  type="text"
                  value={notificationText}
                  onChange={(e) => setNotificationText(e.target.value)}
                  placeholder="Enter notification message"
                  className="flex-1 min-w-0 block w-full px-3 py-2 rounded-md border border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm text-black"
                  disabled={sending}
                  onKeyPress={(e) => {
                    if (e.key === "Enter") {
                      handleSendNotification();
                    }
                  }}
                />
                <button
                  onClick={handleSendNotification}
                  disabled={sending}
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {sending ? "Sending..." : "Send"}
                </button>
              </div>
            </div>
          </div>

          <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Welcome!</h2>
              <p className="text-gray-600">
                You have successfully logged into your Rephi account. This is your home dashboard
                where you can manage your account and access all the features of the application.
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}