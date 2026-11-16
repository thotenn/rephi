import { Socket } from "phoenix";
import { debugLog, getRephiConfig } from "../../config";
import { useAuthStore } from "../../stores/auth.store";

/** Connection state of the shared socket. */
export type SocketStatus = "idle" | "connecting" | "open" | "closed";

type Listener = () => void;
type DropListener = () => void;

/**
 * The one Phoenix socket of the app.
 *
 * - The token travels as Phoenix's `authToken` (in the `Sec-WebSocket-Protocol`
 *   header, never in the URL) and is read from the auth store on every
 *   (re)connect, so a reconnect after a token change sends the current one.
 * - `connect()` reuses the socket while it is open, connecting or waiting to
 *   reconnect: there is never more than one transport alive.
 * - When the server closes the socket on its own (it does on logout, password
 *   change or user deletion), `onDrop` listeners run; the session module uses
 *   that to check whether the session is still valid.
 */
class PhoenixSocket {
  private socket: Socket | null = null;
  private url: string | null = null;
  private status: SocketStatus = "idle";
  private readonly listeners = new Set<Listener>();
  private readonly dropListeners = new Set<DropListener>();

  /**
   * Opens the socket, or returns the existing one. Returns `null` without a
   * session: the server would refuse the connection anyway.
   */
  connect(): Socket | null {
    const { wsUrl } = getRephiConfig();

    if (!useAuthStore.getState().token) {
      this.disconnect();
      return null;
    }

    if (this.socket) {
      if (this.url === wsUrl) {
        // `Socket#connect` is a no-op while the socket is open or connecting.
        this.socket.connect();
        return this.socket;
      }
      // The endpoint was reconfigured: drop the socket bound to the old URL.
      this.disconnect();
    }

    const socket = new Socket(wsUrl, {
      // A function is evaluated on every (re)connect.
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

  /** Closes the socket for good (until the next `connect()`). */
  disconnect(): void {
    const socket = this.socket;
    if (!socket) return;
    this.socket = null;
    this.url = null;
    socket.disconnect();
    this.setStatus("idle");
  }

  /** Replaces the socket with a new one (e.g. after the token changed). */
  reconnect(): Socket | null {
    this.disconnect();
    return this.connect();
  }

  /** The current socket, without creating one. */
  getSocket = (): Socket | null => this.socket;

  getStatus = (): SocketStatus => this.status;

  isConnected(): boolean {
    return this.status === "open";
  }

  /**
   * Called whenever the socket instance or its status changes. Fits
   * `useSyncExternalStore(PhoenixSocket.subscribe, PhoenixSocket.getSocket)`.
   */
  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  /** Called when the socket closes without `disconnect()` being called. */
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
