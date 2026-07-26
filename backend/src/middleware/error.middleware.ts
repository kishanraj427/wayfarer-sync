import { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";

/** Prisma error codes mapped to HTTP statuses; named so they're never confused with app codes like INVALID_REFRESH. */
const PrismaErrorCode = {
  /** Unique-constraint violation, e.g. duplicate email on signup (bug #14). */
  UniqueConstraintViolation: "P2002",
  /** Record-not-found, e.g. update/delete targeting a missing row (bug #21). */
  RecordNotFound: "P2025",
} as const;

type PrismaErrorCode = (typeof PrismaErrorCode)[keyof typeof PrismaErrorCode];

const HttpStatus = {
  BadRequest: 400,
  Conflict: 409,
  NotFound: 404,
  InternalServerError: 500,
} as const;

const ErrorMessage = {
  ValidationFailed: "Validation failed",
  AlreadyExists: "Already exists",
  NotFound: "Not found",
  InternalServerError: "Internal server error",
} as const;

/**
 * Terminal error handler (Express 5 auto-forwards rejected promises here).
 * Always emits { error, success:false } — the mobile client reads body['error'] (R2).
 * Never attach a generic `code` field: 401 + code:'INVALID_REFRESH' from auth.controller.ts
 * is the sole signal that logs the client out; echoing Prisma's `.code` here could collide with it.
 */
export const errorHandler = (err: any, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof ZodError) {
    res.status(HttpStatus.BadRequest).json({
      error: ErrorMessage.ValidationFailed,
      details: err.issues.map((i) => ({ message: i.message, path: i.path })),
      success: false,
    });
    return;
  }

  if (err?.code === PrismaErrorCode.UniqueConstraintViolation) {
    res.status(HttpStatus.Conflict).json({ error: ErrorMessage.AlreadyExists, success: false });
    return;
  }

  if (err?.code === PrismaErrorCode.RecordNotFound) {
    res.status(HttpStatus.NotFound).json({ error: ErrorMessage.NotFound, success: false });
    return;
  }

  console.error(err);
  res.status(HttpStatus.InternalServerError).json({ error: ErrorMessage.InternalServerError, success: false });
};
