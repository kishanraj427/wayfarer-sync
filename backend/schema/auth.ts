import { z } from "zod";
import { userSchema } from "./user";

// Emoji / pictograph / arrow / symbol / regional-indicator / ZWJ / variation-
// selector ranges. Kept in lockstep with the mobile no-emoji formatter
// (mobile/lib/core/util/text_input_rules.dart) so both reject the same set and a
// non-mobile client cannot push characters that crash the DB/BE.
const EMOJI_REGEX =
  /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}\u{20E3}\u{2122}\u{2139}]/u;

export const safeNameSchema = z
  .string()
  .trim()
  .min(1)
  .max(50)
  .refine((value) => !EMOJI_REGEX.test(value), {
    message: "Name must not contain emoji.",
  });

export const signupInputSchema = z.object({
  email: z.email(),
  password: z.string().min(6),
  firstName: safeNameSchema,
  lastName: safeNameSchema,
});

export const loginInputSchema = z.object({
  email: z.email(),
  password: z.string(),
});

export const authResponseSchema = z.object({
  token: z.string(),
  user: userSchema,
});

export type SignupInput = z.infer<typeof signupInputSchema>;
export type LoginInput = z.infer<typeof loginInputSchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
