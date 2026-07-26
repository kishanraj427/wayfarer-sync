import { z } from "zod";
import dotenv from "dotenv";

dotenv.config();

/** JWT_SECRET is min(1), not min(32): rotating it would log out every user (R1). REFRESH_SECRET is new, so it can be strict. */
export const envSchema = z
  .object({
    DATABASE_URL: z.string().min(1),
    JWT_SECRET: z.string().min(1),
    JWT_REFRESH_SECRET: z.string().min(32),
    PORT: z.coerce.number().default(3000),
  })
  /** Secrets must differ, or a refresh token would verify as an access token. Refuse to boot instead. */
  .refine((e) => e.JWT_SECRET !== e.JWT_REFRESH_SECRET, {
    message:
      "JWT_REFRESH_SECRET must differ from JWT_SECRET — identical secrets collapse the access/refresh token separation",
    path: ["JWT_REFRESH_SECRET"],
  });

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("Invalid environment configuration:");
  for (const issue of parsed.error.issues) {
    console.error(`  ${issue.path.join(".")}: ${issue.message}`);
  }
  process.exit(1);
}

export const env = parsed.data;
