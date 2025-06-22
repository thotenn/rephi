import { default as React, ReactNode } from 'react';
import { Socket, Channel } from 'phoenix';

interface PhoenixContextType {
    socket: Socket | null;
    connected: boolean;
    connect: (token: string, socketUrl?: string) => void;
    disconnect: () => void;
    channel: (topic: string, params?: object) => Channel | null;
}
interface PhoenixProviderProps {
    children: ReactNode;
    socketUrl?: string;
    autoConnect?: boolean;
    token?: string;
}
export declare const PhoenixProvider: React.FC<PhoenixProviderProps>;
export declare const usePhoenix: () => PhoenixContextType;
export {};
