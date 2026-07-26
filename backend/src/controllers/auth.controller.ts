import { Request, Response } from "express";
import { AuthRequest, bearerTokenFrom } from "../middleware/auth.middleware";
import { userSchema } from "../../schema";
import { signupInputSchema } from "../../schema/auth";
import * as authService from "../services/auth.service";
import { toJSON } from "@/utils/converter";
import { verifyRefreshToken, verifyAccessToken, signWsTicket } from "../services/token.service";
import { z } from "zod";

/** Contract: 401 + code:'INVALID_REFRESH' is the only signal that ends a client session (R1). Never emit it for transient failures. */
export const INVALID_REFRESH_CODE = "INVALID_REFRESH";

export const signup = async (req: Request, res: Response) => {
  const parsed = signupInputSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? "Invalid input", success: false });
    return;
  }
  const { email, password, firstName, lastName } = parsed.data;

  const existing = await authService.findUserByEmail(email);
  if (existing) {
    res.status(409).json({ error: "Email already exists" });
    return;
  }

  const user = await authService.createUser(email, password, firstName, lastName);
  const tokens = authService.generateTokenSet(user.id);

  res.status(201).json({ ...tokens, user: userSchema.parse(toJSON(user)), success: true });
};

export const login = async (req: Request, res: Response) => {
  const { email, password } = req.body;

  const user = await authService.findUserByEmail(email);
  if (!user) {
    res.status(401).json({ error: "Invalid credentials", success: false });
    return;
  }

  const valid = await authService.verifyPassword(password, user.password);
  if (!valid) {
    res.status(401).json({ error: "Invalid credentials", success: false });
    return;
  }

  const updatedUser = await authService.updateLastLogin(user.id);
  const tokens = authService.generateTokenSet(user.id);

  res.json({
    ...tokens,
    user: userSchema.parse(toJSON(updatedUser)),
    success: true,
  });
};

export const getMe = async (req: AuthRequest, res: Response) => {
  const user = await authService.findUserById(req.userId!);

  if (!user) {
    res.status(404).json({ error: "User not found", success: false });
    return;
  }

  res.json({ user: userSchema.parse(toJSON(user)), success: true });
};

export const refresh = async (req: Request, res: Response) => {
  const token = req.body?.refreshToken;
  const result = typeof token === "string" ? verifyRefreshToken(token) : null;

  if (!result) {
    res.status(401).json({ error: "Invalid or expired refresh token", code: INVALID_REFRESH_CODE, success: false });
    return;
  }

  res.status(200).json({ ...authService.generateTokenSet(result.userId), success: true });
};

/**
 * One-shot upgrade for installs holding an access token but no refresh token. Skips
 * `authenticate` deliberately: its bare 401 reads as transient and would retry forever.
 */
export const exchange = async (req: AuthRequest, res: Response) => {
  const token = bearerTokenFrom(req.headers?.authorization);
  const result = token ? verifyAccessToken(token) : null;

  if (!result) {
    res.status(401).json({
      error: "Invalid or expired credentials",
      code: INVALID_REFRESH_CODE,
      success: false,
    });
    return;
  }

  res.status(200).json({ ...authService.generateTokenSet(result.userId), success: true });
};

export const wsTicket = async (req: AuthRequest, res: Response) => {
  if (!req.userId) {
    res.status(401).json({ error: "Not authenticated", success: false });
    return;
  }
  const parsed = z.uuid().safeParse(req.body?.tripId);
  if (!parsed.success) {
    res.status(400).json({ error: "tripId must be a valid UUID", success: false });
    return;
  }
  res.status(200).json({ ticket: signWsTicket(req.userId, parsed.data), success: true });
};

/** Stateless: nothing server-side to revoke. The client clears its own tokens. */
export const logout = async (_req: Request, res: Response) => {
  res.status(200).json({ success: true });
};
