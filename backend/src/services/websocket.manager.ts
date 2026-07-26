import { WebSocket } from "ws";

// In-memory state tracking: tripId -> Map(userId -> WebSocket instance)
const rooms = new Map<string, Map<string, WebSocket>>();

/** Close code for a missed re-auth deadline. Shared wire constant with the mobile client — value must never change. */
export const AUTH_EXPIRED_CLOSE_CODE = 4001 as const;

/** Human-readable close reason paired with AUTH_EXPIRED_CLOSE_CODE. */
export const AUTH_EXPIRED_CLOSE_REASON = "auth expired";

/**
 * A re-auth deadline bound to the exact socket it was armed for — not just tripId+userId,
 * since a rapid reconnect can occupy the same slot and cause a wrong-socket close (R2).
 */
type ArmedDeadline = { deadline: number; socket: WebSocket };

/** tripId -> userId -> armed deadline for the specific socket it was set on. */
const authDeadlines = new Map<string, Map<string, ArmedDeadline>>();

export const roomManager = {
  /**
   * Tracks an active connection for a user inside a specific trip room.
   * Automatically closes pre-existing connections if a user re-connects.
   */
  addUser(tripId: string, userId: string, socket: WebSocket): void {
    if (!rooms.has(tripId)) {
      rooms.set(tripId, new Map());
    }

    const roomMembers = rooms.get(tripId)!;

    // Defend against stale duplicate sockets if a device reconnects rapidly
    const existingSocket = roomMembers.get(userId);
    if (existingSocket && existingSocket.readyState === WebSocket.OPEN) {
      // Belt and suspenders: clear synchronously so the evicted socket's deadline
      // can't outlive it (removeUser's own identity guard won't catch this case).
      this.clearAuthDeadline(tripId, userId);
      existingSocket.close();
    }

    roomMembers.set(userId, socket);
  },

  /**
   * Removes a user from a room; deletes the room if empty. Only evicts if the closing
   * socket is still the registered one — a rapid reconnect replaces it first, and this
   * guard stops the stale close handler from deleting the new socket's entry.
   */
  removeUser(tripId: string, userId: string, socket: WebSocket): void {
    const roomMembers = rooms.get(tripId);
    if (!roomMembers) return;

    if (roomMembers.get(userId) !== socket) return;

    roomMembers.delete(userId);

    // Garbage collect empty trip rooms
    if (roomMembers.size === 0) {
      rooms.delete(tripId);
    }

    this.clearAuthDeadline(tripId, userId);
  },

  /** Sends a structured payload to all active connections in a room except the sender. */
  broadcastToRoom(
    tripId: string,
    senderUserId: string,
    type: string,
    payload: Record<string, any>,
  ): void {
    const roomMembers = rooms.get(tripId);
    if (!roomMembers) return;

    const messageString = JSON.stringify({ type, payload });

    roomMembers.forEach((socket, userId) => {
      // Never mirror data back to the person who broadcast it
      if (userId !== senderUserId && socket.readyState === WebSocket.OPEN) {
        socket.send(messageString);
      }
    });
  },

  /** Diagnostic: number of active connections in a room. */
  getActiveCount(tripId: string): number {
    return rooms.get(tripId)?.size ?? 0;
  },

  /**
   * Arms a re-auth deadline. Only ticket-authenticated sockets get one; legacy
   * ?token= sockets are never swept, preserving v1.0.4+5 behavior (R2). Binds to
   * whichever socket currently occupies the trip+user slot.
   */
  setAuthDeadline(tripId: string, userId: string, at: number): void {
    const socket = rooms.get(tripId)?.get(userId);
    if (!socket) return; // no live socket to bind this deadline to

    if (!authDeadlines.has(tripId)) authDeadlines.set(tripId, new Map());
    authDeadlines.get(tripId)!.set(userId, { deadline: at, socket });
  },

  /** Disarms a user's re-auth deadline; called on room exit so it can't outlive the connection. */
  clearAuthDeadline(tripId: string, userId: string): void {
    authDeadlines.get(tripId)?.delete(userId);
    if (authDeadlines.get(tripId)?.size === 0) authDeadlines.delete(tripId);
  },

  /**
   * Closes every past-deadline socket with AUTH_EXPIRED_CLOSE_CODE; returns the count.
   * Only closes the socket the deadline was armed for (checked by identity), so an
   * expired deadline can never close a different socket (R2).
   */
  sweepExpiredAuth(now: number): number {
    let closed = 0;
    authDeadlines.forEach((users, tripId) => {
      users.forEach((entry, userId) => {
        if (entry.deadline > now) return;

        const currentSocket = rooms.get(tripId)?.get(userId);
        if (currentSocket === entry.socket) {
          currentSocket.close(AUTH_EXPIRED_CLOSE_CODE, AUTH_EXPIRED_CLOSE_REASON);
          closed++;
        }
        users.delete(userId);
      });
    });
    return closed;
  },
};
