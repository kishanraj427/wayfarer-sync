import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import prisma from "../prisma";
import { getRandomColor } from "@/utils/randomColor";
import { Destination } from "schema";

export const listTrip = () => {
  return prisma.trip.findMany({ where: { deletedAt: null } });
};

export const createTrip = async (
  userId: string,
  trip: {
    title: string;
    startedAt: Date;
    endedAt?: Date;
  },
  destinations: Destination[] = [],
) => {
  return prisma.trip.create({
    data: {
      title: trip.title,
      startedAt: trip.startedAt,
      endedAt: trip.endedAt,
      members: {
        create: {
          userId,
          color: getRandomColor(), // helper to assign a colour
        },
      },
      destinations:
        destinations.length > 0
          ? {
              create: destinations.map((dest, index) => ({
                name: dest.name,
                latitude: dest.latitude,
                longitude: dest.longitude,
                order: dest.order ?? index,
              })),
            }
          : undefined,
    },
    include: { members: true, destinations: true },
  });
};

export const getTripById = (id: string) => {
  return prisma.trip.findUnique({ where: { id, deletedAt: null } });
};

export const updateTripById = async (id: string, trip: { title: string }) => {
  return prisma.trip.update({
    where: {
      id,
    },
    data: {
      title: trip.title,
    },
  });
};

export const deleteTripById = async (id: string) => {
  return prisma.trip.update({
    where: {
      id,
    },
    data: {
      endedAt: new Date(),
      deletedAt: new Date(),
    },
  });
};

export const joinTripById = async (tripId: string, userId: string) => {
  // Check if already a member
  const existing = await prisma.tripMember.findUnique({
    where: { tripId_userId: { tripId, userId } },
  });
  if (existing) {
    return existing;
  }

  const member = await prisma.tripMember.create({
    data: { tripId, userId, color: getRandomColor() },
    include: { user: { select: { id: true, email: true } } },
  });
  return member;
};

export const getTripMembers = async (tripId: string) => {
  return prisma.tripMember.findMany({
    where: { tripId },
    include: { user: { select: { id: true, email: true } } },
  });
};
