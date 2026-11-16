import { Socket } from "phoenix";
import { debugLog, getRephiConfig } from "../../config";
import { useAuthStore } from "../../stores/auth.store";

export type SocketStatus = "idle" | "connecting" | "open" | "closed";

type Listener = () => void;
type DropListener = () => void;

class PhoenixSocket {
  private socket: Socket | null = null;
  private url: string | null = null;
  private status: SocketStatus = "idle";
  private readonly listeners = new Set<Listener>();
  private readonly dropListeners = new Set<DropListener>();

  connect(): Socket | null {
    const { wsUrl } = getRephiConfig();

    if (!useAuthStore.getState().token) {
      this.disconnect();
      return null;
    }

    if (this.socket) {
      if (this.url === wsUrl) {
        this.socket.connect();
        return this.socket;
      }
      this.disconnect();
    }

    const socket = new Socket(wsUrl, {
      // Read on every (re)connect; sent in Sec-WebSocket-Protocol, never in the URL.
      authToken: () => useAuthStore.getState().token ?? "",
      reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000][tries - 1] ?? 10000,
      rejoinAfterMs: (tries) => [1000, 2000, 5000][tries - 1] ?? 5000,
      logger: (kind, msg, data) => debugLog(`socket ${kind}: ${msg}`, data),
    });

    socket.onOpen(() => {
      if (socket === this.socket) this.setStatus("open");
    });
    socket.onClose(() => {
      // Closes of a socket we already dropped (disconnect, reconnect) are ours.
      if (socket !== this.socket) return;
      this.setStatus("closed");
      this.dropListeners.forEach((listener) => listener());
    });

    this.socket = socket;
    this.url = wsUrl;
    this.setStatus("connecting");
    socket.connect();
    return socket;
  }

  disconnect(): void {
    const socket = this.socket;
    if (!socket) return;
    this.socket = null;
    this.url = null;
    if (socket.connectionState() === "connecting") {
      // Closing during the handshake makes browsers log a warning; close once it ends.
      const close = () => socket.disconnect();
      socket.onOpen(close);
      socket.onError(close);
    } else {
      socket.disconnect();
    }
    this.setStatus("idle");
  }

  reconnect(): Socket | null {
    this.disconnect();
    return this.connect();
  }

  getSocket = (): Socket | null => this.socket;

  getStatus = (): SocketStatus => this.status;

  isConnected(): boolean {
    return this.status === "open";
  }

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  onDrop(listener: DropListener): () => void {
    this.dropListeners.add(listener);
    return () => {
      this.dropListeners.delete(listener);
    };
  }

  private setStatus(status: SocketStatus): void {
    this.status = status;
    this.listeners.forEach((listener) => listener());
  }
}

export default new PhoenixSocket();
