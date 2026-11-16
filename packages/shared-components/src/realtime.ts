/** Topic every authenticated socket may join; carries broadcasts to everybody. */
export const LOBBY_TOPIC = "user:lobby";

/** Event pushed by the server on `user:lobby` and `user:<id>`. */
export const NOTIFICATION_EVENT = "new_notification";

/**
 * Topic of one user's own notifications. Only that user may join it; any
 * other user gets the join error `{reason: "unauthorized"}`.
 */
export function userTopic(userId: number | string): string {
  return `user:${userId}`;
}
