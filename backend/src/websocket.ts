import { Server as HttpServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import url from "url";
import jwt from "jsonwebtoken";
import prisma from "./prisma";
import { roomManager } from "./services/websocket.manager";
import * as pathService from "./services/pathPoint.service";
import { z } from "zod";

const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key";

const locationUpdatePayloadSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: z.iso.datetime(),
  accuracy: z.number().min(0).nullable().optional(),
});

export const initWebSocketServer = (server: HttpServer): void => {
  // Create a headless WebSocket server instance
  const wss = new WebSocketServer({ noServer: true });

  /**
   * 1. The HTTP Upgrade Handshake Step
   * Intercepts the raw connection request before accepting it, extracting
   * credentials directly from the query parameter string.
   */
  server.on("upgrade", async (request, socket, head) => {
    const parsedUrl = url.parse(request.url || "", true);
    const { token, tripId } = parsedUrl.query;

    // Simple structural validation before kicking off database lookups
    if (
      !token ||
      !tripId ||
      typeof token !== "string" ||
      typeof tripId !== "string"
    ) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }

    try {
      // Token Verification (matches your auth middleware logic)
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
      const userId = decoded.userId;

      // Membership Authorization check directly via Prisma
      const member = await prisma.tripMember.findUnique({
        where: {
          tripId_userId: { tripId, userId },
        },
        include: {
          trip: true,
        },
      });

      if (!member || member.trip.deletedAt !== null) {
        socket.write("HTTP/1.1 403 Forbidden\r\n\r\n");
        socket.destroy();
        return;
      }

      // If everything checks out, finalize the connection handshake upgrade
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit("connection", ws, userId, tripId);
      });
    } catch (err) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
    }
  });

  /**
   * 2. The Active Connection Event Loop
   * Manages active message passing once a channel has been successfully authorized.
   */
  wss.on("connection", (ws: WebSocket, userId: string, tripId: string) => {
    // Add the fresh validated socket to the structural Room Manager map
    roomManager.addUser(tripId, userId, ws);

    // Listen for real-time location updates coming from the phone
    ws.on("message", async (message: string) => {
      try {
        const data = JSON.parse(message);

        if (data.type === "location_update") {
          const parsedPayload = locationUpdatePayloadSchema.parse(data.payload);
          const { latitude, longitude, timestamp, accuracy } = parsedPayload;

          // A. Broadcast position immediately to everyone else in the group
          roomManager.broadcastToRoom(tripId, userId, "member_location", {
            userId,
            latitude,
            longitude,
            timestamp,
            accuracy: accuracy ?? null,
          });

          // B. Silently persist this individual point using your path service in the background
          pathService
            .ingestPathBatch([
              {
                tripId,
                userId,
                latitude,
                longitude,
                timestamp,
                accuracy: accuracy ?? undefined,
              },
            ])
            .catch((err) =>
              console.error(
                "Error logging background tracking coordinates:",
                err,
              ),
            );
        }
      } catch (err) {
        ws.send(
          JSON.stringify({
            type: "error",
            payload: { message: "Malformed payload frame structure" },
          }),
        );
      }
    });

    // Remove connection entries gracefully when sockets close or disconnect
    ws.on("close", () => {
      roomManager.removeUser(tripId, userId);
    });

    ws.on("error", (err) => {
      console.error(
        `WebSocket connection runtime fault for user ${userId}:`,
        err,
      );
      roomManager.removeUser(tripId, userId);
    });
  });
};
