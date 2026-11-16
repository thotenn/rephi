import { useRealtimeConnected } from "~/lib/realtime";

export default function RealtimeHint() {
  const connected = useRealtimeConnected();

  return (
    <p className="mt-4 text-sm text-gray-500" data-testid="realtime-hint">
      Live notifications: {connected ? "connected" : "not connected"}.
    </p>
  );
}
