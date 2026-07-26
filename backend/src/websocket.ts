import { Server as HttpServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import url from "url";
import prisma from "./prisma";
import { roomManager, AUTH_EXPIRED_CLOSE_CODE, AUTH_EXPIRED_CLOSE_REASON } from "./services/websocket.manager";
import * as pathService from "./services/pathPoint.service";
import { verifyWsTicket, verifyAccessToken } from "./services/token.service";
import { z } from "zod";

/** Max time before a ticketed socket must re-auth via `auth_refresh`. Legacy `?token=` sockets never get one (R2). */
const AUTH_WINDOW_MS = 15 * 60 * 1000;

/** How often the sweep checks for sockets past their re-auth deadline. */
const SWEEP_INTERVAL_MS = 60 * 1000;

/** Message `type` strings on the wire; part of the client/server contract, so values must never change. */
const WsMessageType = {
  LocationUpdate: "location_update",
  MemberLocation: "member_location",
  AuthRefresh: "auth_refresh",
  AuthOk: "auth_ok",
  Error: "error",
} as const;

type WsMessageType = (typeof WsMessageType)[keyof typeof WsMessageType];

/** Raw HTTP responses written to the socket before the upgrade completes. */
const HttpUpgradeResponse = {
  Unauthorized: "HTTP/1.1 401 Unauthorized\r\n\r\n",
} as const;

const locationUpdatePayloadSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: z.iso.datetime(),
  accuracy: z.number().min(0).nullable().optional(),
});

/** Trip membership check for upgrade + `auth_refresh`. Same rule as `requireTripMembership`: "not a member" and "trip deleted" look identical. */
const isActiveMember = async (tripId: string, userId: string): Promise<boolean> => {
  const member = await prisma.tripMember.findUnique({
    where: { tripId_userId: { tripId, userId } },
    include: { trip: { select: { deletedAt: true } } },
  });
  return !!member && member.trip.deletedAt === null;
};

type AuthorizeResult = { userId: string; ticketed: boolean } | null;

/**
 * Resolves upgrade credentials and trip membership. Dual-accept (R2): `?ticket=` is
 * verified and trip-bound via verifyWsTicket; legacy `?token=` via verifyAccessToken,
 * as v1.0.4+5 expects. Only the ticketed branch gets a re-auth deadline.
 */
const authorize = async (query: Record<string, unknown>): Promise<AuthorizeResult> => {
  const tripId = typeof query.tripId === "string" ? query.tripId : null;
  if (!tripId) return null;

  let userId: string | null = null;
  let ticketed = false;

  if (typeof query.ticket === "string") {
    userId = verifyWsTicket(query.ticket, tripId)?.userId ?? null;
    ticketed = true;
  } else if (typeof query.token === "string") {
    // Legacy path (?token=): never armed with a deadline, so the sweep never touches it (R2).
    userId = verifyAccessToken(query.token)?.userId ?? null;
  }
  if (!userId) return null;

  const member = await isActiveMember(tripId, userId);
  if (!member) return null;

  return { userId, ticketed };
};

/** Stops the periodic re-auth sweep and closes the WebSocket server. */
export type WebSocketServerHandle = { dispose: () => void };

export const initWebSocketServer = (server: HttpServer): WebSocketServerHandle => {
  // Create a headless WebSocket server instance
  const wss = new WebSocketServer({ noServer: true });

  /** Upgrade handshake: extracts credentials from the query string before accepting. */
  server.on("upgrade", async (request, socket, head) => {
    // emit() discards this promise, so an unguarded rejection is unhandled and kills
    // the process. Always reject the handshake instead.
    try {
      const parsedUrl = url.parse(request.url || "", true);

      const result = await authorize(parsedUrl.query as Record<string, unknown>);
      if (!result) {
        socket.write(HttpUpgradeResponse.Unauthorized);
        socket.destroy();
        return;
      }

      const { userId, ticketed } = result;
      const tripId = parsedUrl.query.tripId as string;

      // If everything checks out, finalize the connection handshake upgrade
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit("connection", ws, userId, tripId, ticketed);
      });
    } catch (error) {
      console.error("WebSocket upgrade failed:", error);
      socket.write(HttpUpgradeResponse.Unauthorized);
      socket.destroy();
    }
  });

  /** Active connection loop: handles messages once a channel is authorized. */
  wss.on(
    "connection",
    (ws: WebSocket, userId: string, tripId: string, ticketed: boolean) => {
      // Add the fresh validated socket to the structural Room Manager map
      roomManager.addUser(tripId, userId, ws);

      // Only ticket-authenticated connections are put on the re-auth clock;
      // legacy ?token= connections never get a deadline (R2).
      if (ticketed) {
        roomManager.setAuthDeadline(tripId, userId, Date.now() + AUTH_WINDOW_MS);
      }

      // Listen for real-time location updates coming from the phone
      ws.on("message", async (message: string) => {
        try {
          const data = JSON.parse(message);

          if (data.type === WsMessageType.AuthRefresh) {
            const ticket = data.payload?.ticket;
            const verified = typeof ticket === "string" ? verifyWsTicket(ticket, tripId) : null;

            // Re-check membership too — it may have changed since connect.
            const stillMember = verified ? await isActiveMember(tripId, userId) : false;

            if (!verified || verified.userId !== userId || !stillMember) {
              ws.close(AUTH_EXPIRED_CLOSE_CODE, AUTH_EXPIRED_CLOSE_REASON);
              return;
            }

            roomManager.setAuthDeadline(tripId, userId, Date.now() + AUTH_WINDOW_MS);
            ws.send(JSON.stringify({ type: WsMessageType.AuthOk, payload: {} }));
            return;
          }

          if (data.type === WsMessageType.LocationUpdate) {
            const parsedPayload = locationUpdatePayloadSchema.parse(data.payload);
            const { latitude, longitude, timestamp, accuracy } = parsedPayload;

            // A. Broadcast position immediately to everyone else in the group
            roomManager.broadcastToRoom(tripId, userId, WsMessageType.MemberLocation, {
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
              type: WsMessageType.Error,
              payload: { message: "Malformed payload frame structure" },
            }),
          );
        }
      });

      // Remove connection entries gracefully when sockets close or disconnect
      ws.on("close", () => {
        roomManager.removeUser(tripId, userId, ws);
      });

      ws.on("error", (err) => {
        console.error(
          `WebSocket connection runtime fault for user ${userId}:`,
          err,
        );
        roomManager.removeUser(tripId, userId, ws);
      });
    },
  );

  // One interval for all rooms (cheaper than per-socket). Handle is captured so it's
  // stoppable — otherwise a second initWebSocketServer call leaks another interval.
  const sweepInterval = setInterval(
    () => roomManager.sweepExpiredAuth(Date.now()),
    SWEEP_INTERVAL_MS,
  );

  // Defense in depth: stop the sweep if something else closes the wss directly.
  wss.on("close", () => clearInterval(sweepInterval));

  return {
    dispose: () => {
      clearInterval(sweepInterval);
      wss.close();
    },
  };
};
