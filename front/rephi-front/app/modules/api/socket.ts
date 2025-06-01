import { Socket } from "phoenix";
import { SOCKET_URL } from "~/env";
import { useAuthStore } from "~/stores/auth.store";

class PhoenixSocket {
  private socket: Socket | null = null;

  connect() {
    if (this.socket && this.socket.isConnected()) {
      return this.socket;
    }

    const token = useAuthStore.getState().token;
    this.socket = new Socket(SOCKET_URL, {
      params: { token },
      reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000][tries - 1] || 10000,
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
    }
  }

  getSocket(): Socket | null {
    if (!this.socket || !this.socket.isConnected()) {
      return this.connect();
    }
    return this.socket;
  }
}

export default new PhoenixSocket();