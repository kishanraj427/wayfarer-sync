import { Response, NextFunction } from "express";
import { z } from "zod";
import prisma from "../prisma";
import { AuthRequest } from "./auth.middleware";

const HttpStatus = {
  Unauthorized: 401,
  BadRequest: 400,
  NotFound: 404,
} as const;

const ErrorMessage = {
  NotAuthenticated: "Not authenticated",
  InvalidTripId: "Trip ID must be a valid UUID",
  /** Contract: this exact string + 404 (not 403) for both "no such trip" and "not your trip". */
  TripNotFound: "Trip not found",
} as const;

/**
 * 404 (not 403) for non-members — 403 would confirm the trip exists, enabling UUID enumeration.
 * Checks deletedAt only; ended-but-not-deleted trips stay accessible (bug #12, Cluster C).
 */
export const requireTripMembership = async (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.userId) {
    res.status(HttpStatus.Unauthorized).json({ error: ErrorMessage.NotAuthenticated, success: false });
    return;
  }

  const parsed = z.uuid().safeParse(req.params.id);
  if (!parsed.success) {
    res.status(HttpStatus.BadRequest).json({ error: ErrorMessage.InvalidTripId, success: false });
    return;
  }

  const member = await prisma.tripMember.findUnique({
    where: { tripId_userId: { tripId: parsed.data, userId: req.userId } },
    include: { trip: { select: { deletedAt: true } } },
  });

  if (!member || member.trip.deletedAt !== null) {
    res.status(HttpStatus.NotFound).json({ error: ErrorMessage.TripNotFound, success: false });
    return;
  }

  req.tripMember = member;
  next();
};
