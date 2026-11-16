export const LOBBY_TOPIC = "user:lobby";

export const NOTIFICATION_EVENT = "new_notification";

export function userTopic(userId: number | string): string {
  return `user:${userId}`;
}
