import { Socket } from "phoenix";
import { SOCKET_URL } from "~/env";
import { useAuthStore } from "../auth/auth";

const socket = new Socket(SOCKET_URL, {
  params: { token: useAuthStore.getState().token }
});

socket.connect();

export default socket;