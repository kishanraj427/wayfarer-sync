import { test, expect, mock, describe, beforeAll, afterAll } from "bun:test";
import { createServer, Server } from "http";
import WebSocket from "ws";
import jwt from "jsonwebtoken";

// Must be seeded BEFORE importing websocket.ts, which pulls in config/env.
// This file previously hardcoded "your-secret-key" — the fallback the server
// no longer has — so every handshake was rejected and the accept-path tests
// timed out. They were failing for that reason, not for lack of a database:
// prisma is mocked below and no DB is ever contacted.
process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const JWT_SECRET = process.env.JWT_SECRET!;

// Setup mocks
const mockFindUnique = mock(() => Promise.resolve<any>(null));
const mockCreateMany = mock(() => Promise.resolve({ count: 1 }));

mock.module("../prisma", () => ({
  default: {
    tripMember: {
      findUnique: mockFindUnique,
    },
    pathPoint: {
      createMany: mockCreateMany,
    },
  },
}));

const { initWebSocketServer } = await import("../websocket");

describe("WebSocket Server Validation & Security", () => {
  let server: Server;
  let port: number;

  beforeAll((done) => {
    server = createServer((req, res) => {
      res.writeHead(404);
      res.end();
    });
    initWebSocketServer(server);
    server.listen(0, () => {
      const address = server.address();
      if (address && typeof address !== "string") {
        port = address.port;
      }
      done();
    });
  });

  afterAll((done) => {
    server.close(done);
  });

  const getUrl = (token: string, tripId: string) =>
    `ws://localhost:${port}/?token=${token}&tripId=${tripId}`;

  test("reject handshake if query parameters are missing", (done) => {
    const ws = new WebSocket(`ws://localhost:${port}/`);
    ws.on("error", (err) => {
      expect(err).toBeDefined();
      done();
    });
  });

  test("reject handshake with invalid JWT", (done) => {
    const token = "invalid-jwt-token";
    const tripId = "305db518-d069-4592-8db4-998fde0e1e9b";
    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("error", (err) => {
      expect(err).toBeDefined();
      done();
    });
  });

  test("reject handshake if user is not a trip member", (done) => {
    const userId = "user-123";
    const tripId = "trip-456";
    const token = jwt.sign({ userId }, JWT_SECRET);

    mockFindUnique.mockImplementation(() => Promise.resolve(null));

    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("error", (err) => {
      expect(err).toBeDefined();
      done();
    });
  });

  test("reject handshake if trip is soft-deleted", (done) => {
    const userId = "user-123";
    const tripId = "trip-456";
    const token = jwt.sign({ userId }, JWT_SECRET);

    // Mock tripMember found, but the trip is soft-deleted
    mockFindUnique.mockImplementation(() =>
      Promise.resolve({
        id: "member-1",
        tripId,
        userId,
        trip: {
          id: tripId,
          title: "Deleted Trip",
          deletedAt: new Date(),
        },
      }),
    );

    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("error", (err) => {
      expect(err).toBeDefined();
      done();
    });
  });

  test("accept handshake for valid trip member of non-deleted trip", (done) => {
    const userId = "user-123";
    const tripId = "trip-456";
    const token = jwt.sign({ userId }, JWT_SECRET);

    // Mock valid trip member of non-deleted trip
    mockFindUnique.mockImplementation(() =>
      Promise.resolve({
        id: "member-1",
        tripId,
        userId,
        trip: {
          id: tripId,
          title: "Active Trip",
          deletedAt: null,
        },
      }),
    );

    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("open", () => {
      expect(ws.readyState).toBe(WebSocket.OPEN);
      ws.close();
      done();
    });
  });

  test("accept valid location update payload", (done) => {
    const userId = "user-123";
    const tripId = "trip-456";
    const token = jwt.sign({ userId }, JWT_SECRET);

    mockFindUnique.mockImplementation(() =>
      Promise.resolve({
        id: "member-1",
        tripId,
        userId,
        trip: {
          id: tripId,
          title: "Active Trip",
          deletedAt: null,
        },
      }),
    );

    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("open", () => {
      mockCreateMany.mockClear();

      ws.send(
        JSON.stringify({
          type: "location_update",
          payload: {
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: "2026-06-09T12:00:00.000Z",
            accuracy: 5.5,
          },
        }),
      );

      setTimeout(() => {
        expect(mockCreateMany).toHaveBeenCalled();
        ws.close();
        done();
      }, 50);
    });
  });

  test("reject invalid location coordinates (latitude too high)", (done) => {
    const userId = "user-123";
    const tripId = "trip-456";
    const token = jwt.sign({ userId }, JWT_SECRET);

    mockFindUnique.mockImplementation(() =>
      Promise.resolve({
        id: "member-1",
        tripId,
        userId,
        trip: {
          id: tripId,
          title: "Active Trip",
          deletedAt: null,
        },
      }),
    );

    const ws = new WebSocket(getUrl(token, tripId));
    ws.on("open", () => {
      ws.send(
        JSON.stringify({
          type: "location_update",
          payload: {
            latitude: 95.0, // Invalid: latitude must be between -90 and 90
            longitude: -122.4194,
            timestamp: "2026-06-09T12:00:00.000Z",
            accuracy: 5.5,
          },
        }),
      );
    });

    ws.on("message", (msgString) => {
      const msg = JSON.parse(msgString.toString());
      expect(msg.type).toBe("error");
      expect(msg.payload.message).toContain("Malformed payload frame structure");
      ws.close();
      done();
    });
  });
});
