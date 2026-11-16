import { useSyncExternalStore } from "react";
import type { Socket } from "phoenix";
import PhoenixSocket, { type SocketStatus } from "../controllers/api/socket";

const noSocket = () => null;
const idle = (): SocketStatus => "idle";

/** The shared socket and its connection state, re-rendering on every change. */
export function usePhoenixSocket(): { socket: Socket | null; status: SocketStatus; connected: boolean } {
  const socket = useSyncExternalStore(PhoenixSocket.subscribe, PhoenixSocket.getSocket, noSocket);
  const status = useSyncExternalStore(PhoenixSocket.subscribe, PhoenixSocket.getStatus, idle);
  return { socket, status, connected: status === "open" };
}
