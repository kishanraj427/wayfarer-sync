import { Request, Response, NextFunction } from "express";
import { verifyAccessToken } from "../services/token.service";

/** The auth scheme prefix expected on the Authorization header. */
export const BEARER_PREFIX = "Bearer ";

/** Extracts the token from an Authorization header, or null if malformed. */
export const bearerTokenFrom = (header: string | undefined): string | null =>
  header?.startsWith(BEARER_PREFIX) ? header.slice(BEARER_PREFIX.length) : null;

export interface AuthRequest extends Request {
  userId?: string;
  tripMember?: unknown;
}

export const authenticate = (req: AuthRequest, res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith(BEARER_PREFIX)) {
    res.status(401).json({ error: "No token provided", success: false });
    return;
  }

  const result = verifyAccessToken(header.slice(BEARER_PREFIX.length));
  if (!result) {
    res.status(401).json({ error: "Invalid token", success: false });
    return;
  }

  req.userId = result.userId;
  next();
};
