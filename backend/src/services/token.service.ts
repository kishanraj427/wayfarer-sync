import jwt from "jsonwebtoken";
import { env } from "../config/env";

export const ACCESS_TTL = "15m";
export const REFRESH_TTL = "30d";
export const WS_TICKET_TTL = "30s";
/** Matches the pre-existing token lifetime so v1.0.4+5 behavior is unchanged. */
export const LEGACY_TTL = "7d";

/** `type` claim for every minted token; defends against type confusion. Declared once, never as a literal. */
export const TokenType = {
  Access: "access",
  Refresh: "refresh",
  Ws: "ws",
} as const;

export type TokenType = (typeof TokenType)[keyof typeof TokenType];

/** Pinned (not library default) to block alg-substitution; also matches how legacy 7-day tokens were signed. */
const ALGORITHM = "HS256" as const;

const sign = (payload: object, secret: string, expiresIn: string): string =>
  jwt.sign(payload, secret, { expiresIn, algorithm: ALGORITHM } as jwt.SignOptions);

export const signAccessToken = (userId: string) =>
  sign({ userId, type: TokenType.Access }, env.JWT_SECRET, ACCESS_TTL);

export const signRefreshToken = (userId: string) =>
  sign({ userId, type: TokenType.Refresh }, env.JWT_REFRESH_SECRET, REFRESH_TTL);

/** Legacy alias field for clients that predate the token pair. R2. */
export const signLegacyToken = (userId: string) =>
  sign({ userId, type: TokenType.Access }, env.JWT_SECRET, LEGACY_TTL);

export const signWsTicket = (userId: string, tripId: string) =>
  sign({ userId, tripId, type: TokenType.Ws }, env.JWT_SECRET, WS_TICKET_TTL);

const decode = (token: string, secret: string): Record<string, any> | null => {
  try {
    const payload = jwt.verify(token, secret, { algorithms: [ALGORITHM] });
    return typeof payload === "object" && payload !== null ? (payload as Record<string, any>) : null;
  } catch {
    return null;
  }
};

/**
 * Accepts type:'access' or untyped (pre-release) tokens. Refresh tokens fail on secret
 * mismatch; WS tickets share the secret but are rejected by the `type` check below —
 * removing it would let a 30s trip ticket act as a full access token.
 * SUNSET: drop the untyped branch 7 days after deploy, once old tokens expire.
 */
export const verifyAccessToken = (token: string): { userId: string } | null => {
  const payload = decode(token, env.JWT_SECRET);
  if (!payload || typeof payload.userId !== "string") return null;
  const type = payload.type as TokenType | undefined;
  if (type !== undefined && type !== TokenType.Access) return null;
  return { userId: payload.userId };
};

export const verifyRefreshToken = (token: string): { userId: string } | null => {
  const payload = decode(token, env.JWT_REFRESH_SECRET);
  if (!payload || typeof payload.userId !== "string") return null;
  if (payload.type !== TokenType.Refresh) return null;
  return { userId: payload.userId };
};

/** A ticket is bound to one trip; without this check it would open any room. */
export const verifyWsTicket = (token: string, tripId: string): { userId: string } | null => {
  const payload = decode(token, env.JWT_SECRET);
  if (!payload || typeof payload.userId !== "string") return null;
  if (payload.type !== TokenType.Ws) return null;
  if (payload.tripId !== tripId) return null;
  return { userId: payload.userId };
};
