import prisma from "../prisma";

export interface PathPointInput {
  tripId: string;
  userId: string;
  latitude: number;
  longitude: number;
  timestamp: string;
  accuracy?: number;
}

export const ingestPathBatch = async (points: PathPointInput[]) => {
  const formattedPoints = points.map((p) => ({
    tripId: p.tripId,
    userId: p.userId,
    latitude: p.latitude,
    longitude: p.longitude,
    timestamp: new Date(p.timestamp),
    accuracy: p.accuracy ?? null,
  }));

  // skipDuplicates safeguards against 500 crashes if a device
  // experiences a network disconnect mid-sync and retries the batch.
  return prisma.pathPoint.createMany({
    data: formattedPoints,
    skipDuplicates: true,
  });
};

export const getTripPaths = async (
  tripId: string,
  options: { since?: Date; userId?: string },
) => {
  return prisma.pathPoint.findMany({
    where: {
      tripId,
      ...(options.userId && { userId: options.userId }),
      ...(options.since && { timestamp: { gte: options.since } }),
    },
    orderBy: {
      timestamp: "asc",
    },
  });
};
