import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Socket, Channel } from 'phoenix';

interface PhoenixContextType {
  socket: Socket | null;
  connected: boolean;
  connect: (token: string, socketUrl?: string) => void;
  disconnect: () => void;
  channel: (topic: string, params?: object) => Channel | null;
}

const PhoenixContext = createContext<PhoenixContextType | undefined>(undefined);

interface PhoenixProviderProps {
  children: ReactNode;
  socketUrl?: string;
  autoConnect?: boolean;
  token?: string;
}

export const PhoenixProvider: React.FC<PhoenixProviderProps> = ({
  children,
  socketUrl = 'ws://localhost:4000/socket',
  autoConnect = false,
  token
}) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);

  const connect = (authToken: string, customSocketUrl?: string) => {
    if (socket?.isConnected()) {
      console.warn('Socket already connected');
      return;
    }

    const newSocket = new Socket(customSocketUrl || socketUrl, {
      params: { token: authToken }
    });

    newSocket.onOpen(() => {
      console.log('Phoenix socket connected');
      setConnected(true);
    });

    newSocket.onClose(() => {
      console.log('Phoenix socket disconnected');
      setConnected(false);
    });

    newSocket.onError(() => {
      console.error('Phoenix socket error');
      setConnected(false);
    });

    newSocket.connect();
    setSocket(newSocket);
  };

  const disconnect = () => {
    if (socket) {
      socket.disconnect();
      setSocket(null);
      setConnected(false);
    }
  };

  const channel = (topic: string, params: object = {}) => {
    if (!socket || !connected) {
      console.warn('Socket not connected');
      return null;
    }
    return socket.channel(topic, params);
  };

  useEffect(() => {
    if (autoConnect && token) {
      connect(token);
    }

    return () => {
      if (socket?.isConnected()) {
        socket.disconnect();
      }
    };
  }, []);

  const value: PhoenixContextType = {
    socket,
    connected,
    connect,
    disconnect,
    channel
  };

  return (
    <PhoenixContext.Provider value={value}>
      {children}
    </PhoenixContext.Provider>
  );
};

export const usePhoenix = () => {
  const context = useContext(PhoenixContext);
  if (!context) {
    throw new Error('usePhoenix must be used within a PhoenixProvider');
  }
  return context;
};