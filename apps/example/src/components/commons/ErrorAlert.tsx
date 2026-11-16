interface ErrorAlertProps {
  message: string | null | undefined;
  onDismiss?: () => void;
}

/** Red banner with a server message. Renders nothing without a message. */
export default function ErrorAlert({ message, onDismiss }: ErrorAlertProps) {
  if (!message) return null;

  return (
    <div
      className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4 flex justify-between items-start gap-4"
      role="alert"
    >
      <span>{message}</span>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          className="text-red-700 hover:text-red-900 font-bold"
          aria-label="Dismiss"
        >
          &times;
        </button>
      )}
    </div>
  );
}
