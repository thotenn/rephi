import { z } from "zod";

/** Same limits as the server: at least 8 characters, at most 72 bytes (bcrypt). */
export const MIN_PASSWORD_LENGTH = 8;
export const MAX_PASSWORD_BYTES = 72;

const byteLength = (value: string) => new TextEncoder().encode(value).length;

export const passwordField = z
  .string()
  .min(MIN_PASSWORD_LENGTH, `Password must be at least ${MIN_PASSWORD_LENGTH} characters`)
  .refine((value) => byteLength(value) <= MAX_PASSWORD_BYTES, {
    error: `Password must be at most ${MAX_PASSWORD_BYTES} bytes`,
  });

export const registrationSchema = z
  .object({
    email: z.email("Invalid email address"),
    password: passwordField,
    password_confirmation: z.string().min(1, "Please confirm the password"),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: "Passwords don't match",
    path: ["password_confirmation"],
  });

export const changePasswordSchema = z
  .object({
    current_password: z.string().min(1, "Enter your current password"),
    password: passwordField,
    password_confirmation: z.string().min(1, "Please confirm the new password"),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: "Passwords don't match",
    path: ["password_confirmation"],
  });
