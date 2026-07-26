import { test, expect, describe } from "bun:test";

process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const { generateTokenSet } = await import("../services/auth.service");
const { verifyAccessToken, verifyRefreshToken, LEGACY_TTL, ACCESS_TTL } =
  await import("../services/token.service");

const USER_ID = "22222222-2222-4222-8222-222222222222";

/**
 * FROZEN CONTRACT — exact response fields mobile v1.0.4+5 reads. Do not relax an
 * entry to make a change pass; remove one only once telemetry shows no v1.0.4+5 traffic.
 */
const V104_REQUIRED = {
  "POST /auth/login": ["token", "user"],
  "POST /auth/signup": ["token", "user"],
  "GET /auth/me": ["user"],
  "GET /trip": ["data"],
  "GET /trip/:id": ["data"],
  "POST /trip/:id/join": ["data.alreadyMember", "data.member"],
  "POST /trip/:id/end": ["data"],
  "POST /trip/:id/paths/batch": ["data.count"],
  "GET /trip/:id/paths": ["data"],
} as const;

const hasPath = (obj: any, path: string): boolean =>
  path
    .split(".")
    .reduce((acc, key) => (acc == null ? undefined : acc[key]), obj) !== undefined;

describe("v1.0.4+5 response contract", () => {
  test("auth responses stay FLAT — a top-level `data` key would reroute old parsing", () => {
    const loginShape = {
      ...generateTokenSet(USER_ID),
      user: {},
      success: true,
    };

    // ApiClient falls back to the whole body when body['data'] is absent; auth responses rely on that.
    expect(loginShape).not.toHaveProperty("data");

    for (const field of V104_REQUIRED["POST /auth/login"]) {
      expect(hasPath(loginShape, field)).toBe(true);
    }
  });

  test("the legacy `token` field is still present alongside the new pair", () => {
    const tokens = generateTokenSet(USER_ID);
    expect(tokens.token).toBeDefined();
    expect(tokens.accessToken).toBeDefined();
    expect(tokens.refreshToken).toBeDefined();
  });

  test("`token` is a REAL access token the middleware accepts", () => {
    // v1.0.4+5 uses response['token'] as its bearer forever; if it stopped verifying, users get locked out.
    const { token } = generateTokenSet(USER_ID);
    expect(verifyAccessToken(token)?.userId).toBe(USER_ID);
  });

  test("`token` keeps the 7-day lifetime, NOT the 15-minute access lifetime", () => {
    // Deployed client has no refresh logic; shortening `token` would silently log users out mid-trip.
    expect(LEGACY_TTL).toBe("7d");
    expect(ACCESS_TTL).toBe("15m");
    expect(LEGACY_TTL).not.toBe(ACCESS_TTL);
  });

  test("the legacy `token` is NOT usable as a refresh token", () => {
    const { token } = generateTokenSet(USER_ID);
    expect(verifyRefreshToken(token)).toBeNull();
  });

  test("every frozen contract entry names at least one required field", () => {
    for (const [route, fields] of Object.entries(V104_REQUIRED)) {
      expect(fields.length, `${route} has no required fields`).toBeGreaterThan(0);
    }
  });
});
