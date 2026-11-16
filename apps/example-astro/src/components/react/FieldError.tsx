import type { FieldErrors } from "~/lib/rephi";
import { humanizeField } from "~/lib/rephi";

interface FieldErrorProps {
  errors: FieldErrors;
  field: string;
}

/** The server's messages for one input, e.g. "Slug has already been taken". */
export default function FieldError({ errors, field }: FieldErrorProps) {
  const messages = errors[field];
  if (!messages?.length) return null;

  return (
    <p className="text-sm text-red-600 mt-1" data-field-error={field}>
      {humanizeField(field)} {messages.join(", ")}
    </p>
  );
}
