import { test, expect, describe } from "bun:test";
import jwt from "jsonwebtoken";

process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const {
  signAccessToken, signRefreshToken, signLegacyToken, signWsTicket,
  verifyAccessToken, verifyRefreshToken, verifyWsTicket,
} = await import("../services/token.service");

const USER_ID = "22222222-2222-4222-8222-222222222222";
const TRIP_ID = "11111111-1111-4111-8111-111111111111";

describe("token type confusion (the defining stateless vulnerability)", () => {
  test("a refresh token is REJECTED by verifyAccessToken", () => {
    expect(verifyAccessToken(signRefreshToken(USER_ID))).toBeNull();
  });

  test("an access token is REJECTED by verifyRefreshToken", () => {
    expect(verifyRefreshToken(signAccessToken(USER_ID))).toBeNull();
  });

  test("a ws ticket is REJECTED by verifyAccessToken", () => {
    expect(verifyAccessToken(signWsTicket(USER_ID, TRIP_ID))).toBeNull();
  });

  // Remaining direction pairs, safe by construction — asserted so a future edit can't quietly break it.
  test("a ws ticket is REJECTED by verifyRefreshToken", () => {
    expect(verifyRefreshToken(signWsTicket(USER_ID, TRIP_ID))).toBeNull();
  });

  test("an access token is REJECTED by verifyWsTicket", () => {
    expect(verifyWsTicket(signAccessToken(USER_ID), TRIP_ID)).toBeNull();
  });

  test("an untyped legacy token is REJECTED by verifyWsTicket", () => {
    const untyped = jwt.sign({ userId: USER_ID }, process.env.JWT_SECRET!, { expiresIn: "7d" });
    expect(verifyWsTicket(untyped, TRIP_ID)).toBeNull();
  });
});

describe("algorithm pinning", () => {
  test("an alg:none token is REJECTED even though it carries valid claims", () => {
    const forged = jwt.sign(
      { userId: USER_ID, type: "access" },
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      null as any,
      { algorithm: "none" },
    );
    expect(verifyAccessToken(forged)).toBeNull();
  });
});

describe("backward compatibility (R2)", () => {
  test("an untyped legacy token is ACCEPTED by verifyAccessToken", () => {
    const untyped = jwt.sign({ userId: USER_ID }, process.env.JWT_SECRET!, { expiresIn: "7d" });
    expect(verifyAccessToken(untyped)?.userId).toBe(USER_ID);
  });

  test("an untyped legacy token is REJECTED by verifyRefreshToken", () => {
    const untyped = jwt.sign({ userId: USER_ID }, process.env.JWT_SECRET!, { expiresIn: "7d" });
    expect(verifyRefreshToken(untyped)).toBeNull();
  });

  test("signLegacyToken produces a token verifyAccessToken accepts", () => {
    expect(verifyAccessToken(signLegacyToken(USER_ID))?.userId).toBe(USER_ID);
  });
});

describe("ws ticket scoping", () => {
  test("a ticket for trip A is REJECTED when presented for trip B", () => {
    const ticket = signWsTicket(USER_ID, TRIP_ID);
    expect(verifyWsTicket(ticket, "99999999-9999-4999-8999-999999999999")).toBeNull();
  });

  test("a ticket for trip A is ACCEPTED for trip A", () => {
    expect(verifyWsTicket(signWsTicket(USER_ID, TRIP_ID), TRIP_ID)?.userId).toBe(USER_ID);
  });
});

describe("happy paths and tampering", () => {
  test("access and refresh round-trip", () => {
    expect(verifyAccessToken(signAccessToken(USER_ID))?.userId).toBe(USER_ID);
    expect(verifyRefreshToken(signRefreshToken(USER_ID))?.userId).toBe(USER_ID);
  });

  test("garbage input returns null rather than throwing", () => {
    expect(verifyAccessToken("not-a-jwt")).toBeNull();
    expect(verifyRefreshToken("")).toBeNull();
  });

  test("an expired token returns null", () => {
    const expired = jwt.sign({ userId: USER_ID, type: "access" }, process.env.JWT_SECRET!, { expiresIn: "-1s" });
    expect(verifyAccessToken(expired)).toBeNull();
  });
});
