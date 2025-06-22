import { Channel } from 'phoenix';

interface UseChannelOptions {
    onJoin?: () => void;
    onError?: (error: any) => void;
    onClose?: () => void;
}
export declare const useChannel: (topic: string, params?: object, options?: UseChannelOptions) => {
    channel: Channel | null;
    joined: boolean;
    join: () => void;
    leave: () => void;
    push: (event: string, payload?: object) => import('phoenix').Push | null;
    on: (event: string, callback: (payload: any) => void) => () => void;
};
export {};
