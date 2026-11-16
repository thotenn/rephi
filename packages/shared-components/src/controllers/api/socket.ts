import { Socket } from "phoenix";
import { getRephiConfig } from "../../config";
import { useAuthStore } from "../../stores/auth.store";

class PhoenixSocket {
  private socket: Socket | null = null;
  private url: string | null = null;

  connect() {
    const { wsUrl } = getRephiConfig();

    if (this.socket) {
      if (this.url === wsUrl) {
        // Reuse the socket whether it is open, still connecting or waiting to
        // reconnect: creating another one here would leave two transports alive.
        // `Socket#connect` is a no-op while a connection attempt is in flight.
        this.socket.connect();
        return this.socket;
      }
      // The endpoint was reconfigured: drop the socket bound to the old URL.
      this.socket.disconnect();
    }

    this.url = wsUrl;
    this.socket = new Socket(wsUrl, {
      // A function is evaluated on every (re)connect, so a token that changed
      // since the first connection is the one sent after a reconnect.
      params: () => ({ token: useAuthStore.getState().token }),
      reconnectAfterMs: (tries) =>
        [1000, 2000, 5000, 10000][tries - 1] || 10000,
      rejoinAfterMs: (tries) => [1000, 2000, 5000][tries - 1] || 5000,
      logger: (kind, msg, data) => {
        if (process.env.NODE_ENV === "development") {
          console.log(`${kind}: ${msg}`, data);
        }
      },
    });

    this.socket.onError((error) => console.error("Socket error:", error));
    this.socket.connect();
    return this.socket;
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.url = null;
    }
  }

  getSocket(): Socket | null {
    // `connect()` returns the existing socket when there is one, including while
    // it is still connecting (channels can be joined before the socket opens).
    return this.connect();
  }
}

export default new PhoenixSocket();
