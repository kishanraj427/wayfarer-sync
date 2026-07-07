import { WebSocket } from "ws";

// In-memory state tracking: tripId -> Map(userId -> WebSocket instance)
const rooms = new Map<string, Map<string, WebSocket>>();

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
      existingSocket.close();
    }

    roomMembers.set(userId, socket);
  },

  /**
   * Clears a user from a room's active tracking collection.
   * Cleanly deletes the parent trip room if no members remain to save memory.
   *
   * Only evicts when the closing socket is the one currently registered. On a
   * rapid reconnect addUser replaces the socket synchronously, but the OLD
   * socket's close/error handler fires a tick later — without this guard it
   * would delete the entry now pointing at the NEW socket, silently cutting the
   * user off from receiving other members' broadcasts.
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
  },

  /**
   * Dispatches a structured text payload to all active connections
   * in a trip room EXCEPT the originating sender.
   */
  broadcastToRoom(
    tripId: string,
    senderUserId: string,
    type: string,
    payload: Record<string, any>,
  ): number {
    const roomMembers = rooms.get(tripId);
    if (!roomMembers) return 0;

    const messageString = JSON.stringify({ type, payload });

    let recipientCount = 0;
    roomMembers.forEach((socket, userId) => {
      // Never mirror data back to the person who broadcast it
      if (userId !== senderUserId && socket.readyState === WebSocket.OPEN) {
        socket.send(messageString);
        recipientCount++;
      }
    });
    return recipientCount;
  },

  /**
   * Diagnostic utility to verify room density during development testing.
   */
  getActiveCount(tripId: string): number {
    return rooms.get(tripId)?.size ?? 0;
  },
};
