import { test, expect, describe } from "bun:test";

// Seed required vars first so this suite is hermetic and never depends on a local .env.
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";
process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);

// Imported, NOT re-declared. A local copy would pass even if env.ts regressed.
const { envSchema } = await import("../config/env");

const VALID = {
  DATABASE_URL: "postgresql://u:p@localhost:5433/db",
  JWT_SECRET: "short-but-grandfathered",
  JWT_REFRESH_SECRET: "a".repeat(32),
};

describe("env schema", () => {
  test("accepts a short JWT_SECRET (grandfathered, must not force rotation)", () => {
    expect(envSchema.safeParse({ ...VALID, JWT_SECRET: "x" }).success).toBe(true);
  });

  test("rejects a JWT_REFRESH_SECRET under 32 characters", () => {
    expect(envSchema.safeParse({ ...VALID, JWT_REFRESH_SECRET: "tooshort" }).success).toBe(false);
  });

  test("rejects a missing JWT_REFRESH_SECRET", () => {
    const { JWT_REFRESH_SECRET, ...rest } = VALID;
    expect(envSchema.safeParse(rest).success).toBe(false);
  });

  test("rejects JWT_REFRESH_SECRET being identical to JWT_SECRET", () => {
    const same = "s".repeat(40);
    expect(
      envSchema.safeParse({ ...VALID, JWT_SECRET: same, JWT_REFRESH_SECRET: same }).success,
    ).toBe(false);
  });

  test("defaults PORT to 3000 and coerces a string port", () => {
    expect(envSchema.parse(VALID).PORT).toBe(3000);
    expect(envSchema.parse({ ...VALID, PORT: "4000" }).PORT).toBe(4000);
  });
});
