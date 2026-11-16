import type { RephiNotification } from "@rephi/shared-components";

export default function NotificationToast({ notification }: { notification: RephiNotification }) {
  return (
    <span className="flex flex-col">
      <span>{notification.message}</span>
      <span className="text-xs text-gray-500">
        {notification.from ? `From ${notification.from.email}` : "System notification"}
      </span>
    </span>
  );
}
