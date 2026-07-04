import { z } from "zod";
import { baseSchema } from "./base";


export const userSchema = baseSchema.extend({
  email: z.email(),
  firstName: z.string().nullable(),
  lastName: z.string().nullable(),
  lastLoginAt: z.iso.datetime().optional().readonly(),
});

export type User = z.infer<typeof userSchema>;