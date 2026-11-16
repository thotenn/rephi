import { useEffect, useRef, useState } from "react";
import { useLocation } from "react-router";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import {
  broadcastNotification,
  describeError,
  sendTestNotification,
  usePermissions,
} from "@rephi/shared-components";
import { NOTIFY_HASH } from "~/config/routes";
import { dashboardKey } from "~/modules/api/dashboard";
import { useRealtime } from "~/realtime/context";

const BROADCAST_PERMISSION = "notifications:broadcast";
const MAX_MESSAGE_LENGTH = 500;
const DEFAULT_TEST_MESSAGE = "This is a test notification";

/**
 * Sends notifications: to every connected user (with `notifications:broadcast`) or, for
 * anyone, a test to the user's own tabs. Incoming ones are shown by `RealtimeProvider`.
 */
export default function NotificationSender() {
  const { can } = usePermissions();
  const { connected } = useRealtime();
  const queryClient = useQueryClient();
  const [text, setText] = useState("");
  const [fieldError, setFieldError] = useState<string | null>(null);
  const messageRef = useRef<HTMLInputElement>(null);
  const { hash, key } = useLocation();
  const canBroadcast = can(BROADCAST_PERMISSION);

  // `key` refocuses the field when the same link is followed again.
  useEffect(() => {
    if (canBroadcast && hash === NOTIFY_HASH) messageRef.current?.focus();
  }, [canBroadcast, hash, key]);

  const onError = (error: unknown) => {
    const { message, fieldErrors } = describeError(error, "Failed to send notification");
    if (fieldErrors.message) {
      setFieldError(`Message ${fieldErrors.message.join(", ")}`);
    } else {
      toast.error(message);
    }
  };

  const onSent = (feedback: string) => {
    setText("");
    toast.success(feedback);
    void queryClient.invalidateQueries({ queryKey: dashboardKey });
  };

  const broadcast = useMutation({
    mutationFn: broadcastNotification,
    onSuccess: () => onSent("Notification sent!"),
    onError,
  });

  const selfTest = useMutation({
    mutationFn: sendTestNotification,
    onSuccess: () => onSent("Test notification sent to you"),
    onError,
  });

  const pending = broadcast.isPending || selfTest.isPending;

  const submitBroadcast = () => {
    setFieldError(null);
    const message = text.trim();
    if (!message) {
      setFieldError("Please enter a notification message");
      return;
    }
    broadcast.mutate(message);
  };

  const submitSelfTest = () => {
    setFieldError(null);
    selfTest.mutate(text.trim() || DEFAULT_TEST_MESSAGE);
  };

  const buttonClass =
    "inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed";

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
          {canBroadcast
            ? "Send a notification to all connected users, or a test only to yourself."
            : "Send a test notification to yourself: only your own open tabs receive it. Sending to everyone requires the notifications:broadcast permission."}
        </p>
        <div className="mb-4">
          <span
            data-testid="realtime-status"
            className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
              connected ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
            }`}
          >
            {connected ? "🟢 Connected" : "🔴 Disconnected"}
          </span>
        </div>
        <div className="flex flex-wrap gap-3">
          <input
            ref={messageRef}
            type="text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={canBroadcast ? "Enter notification message" : DEFAULT_TEST_MESSAGE}
            aria-label="Notification message"
            aria-invalid={fieldError ? true : undefined}
            maxLength={MAX_MESSAGE_LENGTH}
            className="flex-1 min-w-0 block w-full px-3 py-2 rounded-md border border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm text-black"
            disabled={pending}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                if (canBroadcast) submitBroadcast();
                else submitSelfTest();
              }
            }}
          />
          {canBroadcast && (
            <button
              type="button"
              onClick={submitBroadcast}
              disabled={pending}
              className={`${buttonClass} border-transparent text-white bg-indigo-600 hover:bg-indigo-700`}
            >
              {broadcast.isPending ? "Sending..." : "Send"}
            </button>
          )}
          <button
            type="button"
            onClick={submitSelfTest}
            disabled={pending}
            className={`${buttonClass} border-gray-300 text-gray-700 bg-white hover:bg-gray-50`}
          >
            {selfTest.isPending ? "Sending..." : "Send a test to myself"}
          </button>
        </div>
        {fieldError && <p className="mt-2 text-sm text-red-600">{fieldError}</p>}
      </div>
    </section>
  );
}
