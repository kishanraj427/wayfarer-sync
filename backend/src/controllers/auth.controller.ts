import { Request, Response } from "express";
import { AuthRequest } from "../middleware/auth.middleware";
import { userSchema } from "../../schema";
import { signupInputSchema } from "../../schema/auth";
import * as authService from "../services/auth.service";
import { toJSON } from "@/utils/converter";

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
  const token = authService.generateToken(user.id);

  res.status(201).json({ token, user: userSchema.parse(toJSON(user)), success: true });
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
  const token = authService.generateToken(user.id);

  res.json({
    token,
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
