/** Payload of the `new_notification` event on `user:lobby` and `user:<id>`. */
export interface RephiNotification {
  /** Plain text: render it as text, never as HTML. */
  message: string;
  /** ISO 8601, UTC. */
  timestamp: string;
  type: string;
  /** Who sent it; `null` for notifications emitted by the system itself. */
  from: { id: number; email: string } | null;
}
