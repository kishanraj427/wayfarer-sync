import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import prisma from "../prisma";

export const findUserByEmail = (email: string) => {
  return prisma.user.findUnique({ where: { email } });
};

export const findUserById = (id: string) => {
  return prisma.user.findUnique({ where: { id } });
};

export const createUser = async (email: string, password: string) => {
  const hashed = await bcrypt.hash(password, 10);
  return prisma.user.create({
    data: { email, password: hashed, lastLoginAt: new Date() },
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

export const generateToken = (userId: string) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET!, { expiresIn: "7d" });
};