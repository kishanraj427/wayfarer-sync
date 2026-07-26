import { test, expect, describe } from "bun:test";
import jwt from "jsonwebtoken";

process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const { authenticate } = await import("../middleware/auth.middleware");
const { signAccessToken, signRefreshToken, signWsTicket } = await import(
  "../services/token.service"
);

const USER_ID = "22222222-2222-4222-8222-222222222222";
const TRIP_ID = "11111111-1111-4111-8111-111111111111";

const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => ((res.statusCode = c), res);
  res.json = (b: any) => ((res.body = b), res);
  return res;
};
const run = (authHeader?: string) => {
  const req: any = { headers: authHeader ? { authorization: authHeader } : {} };
  const res = makeRes();
  let nexted = false;
  authenticate(req, res, () => { nexted = true; });
  return { req, res, nexted };
};

describe("authenticate", () => {
  test("accepts a typed access token and sets userId", () => {
    const { req, nexted } = run(`Bearer ${signAccessToken(USER_ID)}`);
    expect(nexted).toBe(true);
    expect(req.userId).toBe(USER_ID);
  });

  test("accepts an untyped legacy token (R2)", () => {
    const untyped = jwt.sign({ userId: USER_ID }, process.env.JWT_SECRET!, { expiresIn: "7d" });
    const { req, nexted } = run(`Bearer ${untyped}`);
    expect(nexted).toBe(true);
    expect(req.userId).toBe(USER_ID);
  });

  test("REJECTS a refresh token presented as an access token", () => {
    const { res, nexted } = run(`Bearer ${signRefreshToken(USER_ID)}`);
    expect(nexted).toBe(false);
    expect(res.statusCode).toBe(401);
  });

  // The case the `type` check exists for: a WS ticket shares the access-token secret,
  // so only the type claim rejects it (unlike the refresh case above).
  test("REJECTS a ws ticket presented as a Bearer access token", () => {
    const { res, nexted } = run(`Bearer ${signWsTicket(USER_ID, TRIP_ID)}`);
    expect(nexted).toBe(false);
    expect(res.statusCode).toBe(401);
  });

  test("rejects a missing header", () => {
    const { res, nexted } = run(undefined);
    expect(nexted).toBe(false);
    expect(res.statusCode).toBe(401);
  });

  test("rejects a non-Bearer header", () => {
    const { res } = run("Basic abc123");
    expect(res.statusCode).toBe(401);
  });
});
