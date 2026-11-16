export interface RephiNotification {
  /** Plain text: render it as text, never as HTML. */
  message: string;
  timestamp: string;
  type: string;
  from: { id: number; email: string } | null;
}
