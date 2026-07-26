import bcrypt from "bcryptjs";
import prisma from "../prisma";
import { signAccessToken, signRefreshToken, signLegacyToken } from "./token.service";

export const findUserByEmail = (email: string) => {
  return prisma.user.findUnique({ where: { email } });
};

export const findUserById = (id: string) => {
  return prisma.user.findUnique({ where: { id } });
};

export const createUser = async (
  email: string,
  password: string,
  firstName: string,
  lastName: string,
) => {
  const hashed = await bcrypt.hash(password, 10);
  return prisma.user.create({
    data: { email, password: hashed, firstName, lastName, lastLoginAt: new Date() },
  });
};

export const verifyPassword = (plain: string, hashed: string) => {
  return bcrypt.compare(plain, hashed);
};

export const updateLastLogin = (userId: string) => {
  return prisma.user.update({
    where: { id: userId },
    data: { lastLoginAt: new Date() },
  });
};

export const generateTokenSet = (userId: string) => ({
  /** Legacy alias — v1.0.4+5 reads response['token'] with a non-nullable cast. R2. */
  token: signLegacyToken(userId),
  accessToken: signAccessToken(userId),
  refreshToken: signRefreshToken(userId),
});