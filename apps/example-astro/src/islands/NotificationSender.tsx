import { useState } from "react";
import { toast } from "react-hot-toast";
import { useRealtimeConnected } from "~/lib/realtime";
import { api, env } from "~/lib/rephi";

/**
 * Form that broadcasts a notification to every connected user, with the state
 * of the realtime connection. Incoming notifications are displayed by the
 * `AppRuntime` island, not here.
 */
export default function NotificationSender() {
  const [notificationText, setNotificationText] = useState("");
  const [sending, setSending] = useState(false);
  const connected = useRealtimeConnected();

  const handleSendNotification = async () => {
    if (!notificationText.trim()) {
      toast.error("Please enter a notification message");
      return;
    }

    setSending(true);
    try {
      await api.post(env.API.sockets.notifications, {
        message: notificationText,
      });
      setNotificationText("");
      toast.success("Notification sent!");
    } catch {
      toast.error("Failed to send notification");
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">
          Send Notification
        </h2>
        <p className="text-gray-600 mb-4">
          Send a notification to all connected users
        </p>
        <div className="mb-4">
          <span
            data-testid="realtime-status"
            className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
              connected
                ? "bg-green-100 text-green-800"
                : "bg-red-100 text-red-800"
            }`}
          >
            {connected ? "🟢 Connected" : "🔴 Disconnected"}
          </span>
        </div>
        <div className="flex space-x-3">
          <input
            type="text"
            value={notificationText}
            onChange={(e) => setNotificationText(e.target.value)}
            placeholder="Enter notification message"
            aria-label="Notification message"
            className="flex-1 min-w-0 block w-full px-3 py-2 rounded-md border border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm text-black"
            disabled={sending}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                handleSendNotification();
              }
            }}
          />
          <button
            type="button"
            onClick={handleSendNotification}
            disabled={sending}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {sending ? "Sending..." : "Send"}
          </button>
        </div>
      </div>
    </div>
  );
}
