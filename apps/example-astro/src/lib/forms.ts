import type { FieldValues, Path, UseFormSetError } from "react-hook-form";
import {
  describeError,
  fieldErrorsToMessage,
  humanizeField,
  type FieldErrors,
} from "~/lib/rephi";

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
