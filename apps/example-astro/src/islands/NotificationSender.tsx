import { useEffect, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { api, describeError, usePermissions } from "~/lib/rephi";
import IslandProviders from "~/components/react/IslandProviders";
import { useRealtimeConnected } from "~/lib/realtime";
import { NOTIFY_HASH } from "~/lib/routes";

/** Permission the server requires to broadcast. */
const BROADCAST_PERMISSION = "notifications:broadcast";
const MAX_MESSAGE_LENGTH = 500;

/**
 * Broadcasts a notification to every connected user. Only rendered for users
 * with `notifications:broadcast`; incoming notifications are shown by
 * the `AppRuntime` island, not here.
 */
function NotificationSenderForm() {
  const { can } = usePermissions();
  const connected = useRealtimeConnected();
  const [text, setText] = useState("");
  const [fieldError, setFieldError] = useState<string | null>(null);
  const messageRef = useRef<HTMLInputElement>(null);
  const allowed = can(BROADCAST_PERMISSION);

  // The client router may set the hash after this island mounts.
  useEffect(() => {
    if (!allowed) return;
    const focusIfRequested = () => {
      if (window.location.hash === NOTIFY_HASH) messageRef.current?.focus();
    };
    focusIfRequested();
    document.addEventListener("astro:page-load", focusIfRequested);
    return () => document.removeEventListener("astro:page-load", focusIfRequested);
  }, [allowed]);

  const send = useMutation({
    mutationFn: (message: string) => api.post("/notifications/broadcast", { message }),
    onSuccess: () => {
      setText("");
      toast.success("Notification sent!");
    },
    onError: (error) => {
      const { message, fieldErrors } = describeError(error, "Failed to send notification");
      if (fieldErrors.message) {
        setFieldError(`Message ${fieldErrors.message.join(", ")}`);
      } else {
        toast.error(message);
      }
    },
  });

  if (!allowed) return null;

  const submit = () => {
    setFieldError(null);
    const message = text.trim();
    if (!message) {
      setFieldError("Please enter a notification message");
      return;
    }
    send.mutate(message);
  };

  return (
    <section
      id={NOTIFY_HASH.slice(1)}
      aria-labelledby="notify-title"
      className="mt-8 bg-white overflow-hidden shadow rounded-lg"
    >
      <div className="px-4 py-5 sm:p-6">
        <h2 id="notify-title" className="text-lg font-medium text-gray-900 mb-4">
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
            ref={messageRef}
            type="text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Enter notification message"
            aria-label="Notification message"
            aria-invalid={fieldError ? true : undefined}
            maxLength={MAX_MESSAGE_LENGTH}
            className="flex-1 min-w-0 block w-full px-3 py-2 rounded-md border border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm text-black"
            disabled={send.isPending}
            onKeyDown={(e) => {
              if (e.key === "Enter") submit();
            }}
          />
          <button
            type="button"
            onClick={submit}
            disabled={send.isPending}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {send.isPending ? "Sending..." : "Send"}
          </button>
        </div>
        {fieldError && <p className="mt-2 text-sm text-red-600">{fieldError}</p>}
      </div>
    </section>
  );
}

export default function NotificationSender() {
  return (
    <IslandProviders>
      <NotificationSenderForm />
    </IslandProviders>
  );
}
