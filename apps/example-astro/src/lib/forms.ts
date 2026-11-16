import type { FieldValues, Path, UseFormSetError } from "react-hook-form";
import {
  describeError,
  fieldErrorsToMessage,
  humanizeField,
  type FieldErrors,
} from "~/lib/rephi";

/**
 * Shows a failed request on a react-hook-form form: the server's field errors
 * go under the matching inputs, and whatever has no input (a general error, a
 * 429, a field the form does not show) is returned for a banner.
 */
export function applyServerErrors<T extends FieldValues>(
  error: unknown,
  setError: UseFormSetError<T>,
  fields: readonly Path<T>[]
): string | null {
  const { message, fieldErrors } = describeError(error);
  if (Object.keys(fieldErrors).length === 0) return message;

  const unmatched: FieldErrors = {};
  for (const [field, messages] of Object.entries(fieldErrors)) {
    if ((fields as readonly string[]).includes(field)) {
      setError(field as Path<T>, {
        type: "server",
        message: `${humanizeField(field)} ${messages.join(", ")}`,
      });
    } else {
      unmatched[field] = messages;
    }
  }
  return Object.keys(unmatched).length > 0 ? fieldErrorsToMessage(unmatched) : null;
}
