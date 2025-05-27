export const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000/api';
export const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'ws://localhost:4000/socket';

export const apisUrl = {
    default: API_URL,
    socket: SOCKET_URL,
}