import { test, expect, mock, describe, beforeEach } from "bun:test";
import jwt from "jsonwebtoken";

process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const mockUserFindUnique = mock((_a: any) => Promise.resolve<any>(null));
// Includes create because mock.module() replacements persist across files in Bun,
// and sibling suite auth.test.ts needs it on the same "../prisma" module.
const mockUserCreate = mock((_a: any) => Promise.resolve<any>(null));
mock.module("../prisma", () => ({
  default: { user: { findUnique: mockUserFindUnique, create: mockUserCreate } },
}));

const { refresh, exchange, logout } = await import("../controllers/auth.controller");
const { signRefreshToken, signAccessToken, verifyAccessToken, verifyRefreshToken } =
  await import("../services/token.service");

const USER_ID = "22222222-2222-4222-8222-222222222222";

const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => ((res.statusCode = c), res);
  res.json = (b: any) => ((res.body = b), res);
  return res;
};

describe("POST /auth/refresh", () => {
  beforeEach(() => mockUserFindUnique.mockClear());

  test("returns a NEW pair for a valid refresh token (sliding rotation)", async () => {
    const res = makeRes();
    await refresh({ body: { refreshToken: signRefreshToken(USER_ID) } } as any, res);

    expect(res.statusCode).toBe(200);
    expect(verifyAccessToken(res.body.accessToken)?.userId).toBe(USER_ID);
    expect(verifyRefreshToken(res.body.refreshToken)?.userId).toBe(USER_ID);
  });

  test("returns 401 with code INVALID_REFRESH for garbage — the ONLY session-dead signal", async () => {
    const res = makeRes();
    await refresh({ body: { refreshToken: "garbage" } } as any, res);

    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });

  test("returns 401 INVALID_REFRESH when an ACCESS token is submitted", async () => {
    const res = makeRes();
    await refresh({ body: { refreshToken: signAccessToken(USER_ID) } } as any, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });

  test("returns 401 INVALID_REFRESH when the field is missing", async () => {
    const res = makeRes();
    await refresh({ body: {} } as any, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });

  test("response has NO top-level data key (old clients depend on the flat shape)", async () => {
    const res = makeRes();
    await refresh({ body: { refreshToken: signRefreshToken(USER_ID) } } as any, res);
    expect(res.body.data).toBeUndefined();
  });
});

const bearer = (token: string) => ({ headers: { authorization: `Bearer ${token}` } });

describe("POST /auth/exchange", () => {
  test("returns a pair for a valid access token", async () => {
    const res = makeRes();
    await exchange(bearer(signAccessToken(USER_ID)) as any, res);

    expect(res.statusCode).toBe(200);
    expect(verifyAccessToken(res.body.accessToken)?.userId).toBe(USER_ID);
    expect(verifyRefreshToken(res.body.refreshToken)?.userId).toBe(USER_ID);
  });

  test("accepts a legacy untyped token — this is the whole point of the endpoint", async () => {
    const untyped = jwt.sign({ userId: USER_ID }, process.env.JWT_SECRET!, { expiresIn: "7d" });
    const res = makeRes();
    await exchange(bearer(untyped) as any, res);
    expect(res.statusCode).toBe(200);
  });

  test("an EXPIRED token returns INVALID_REFRESH, not a bare 401", async () => {
    // A bare 401 would read as transient, stranding the install permanently.
    const expired = jwt.sign({ userId: USER_ID, type: "access" }, process.env.JWT_SECRET!, {
      expiresIn: "-1s",
    });
    const res = makeRes();
    await exchange(bearer(expired) as any, res);

    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });

  test("REJECTS a refresh token presented as the bearer", async () => {
    const res = makeRes();
    await exchange(bearer(signRefreshToken(USER_ID)) as any, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });

  test("returns 401 without an authenticated user", async () => {
    const res = makeRes();
    await exchange({ headers: {} } as any, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("INVALID_REFRESH");
  });
});

describe("POST /auth/logout", () => {
  test("always returns 200 and claims no revocation", async () => {
    const res = makeRes();
    await logout({} as any, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
