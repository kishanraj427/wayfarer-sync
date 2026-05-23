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
   */
  removeUser(tripId: string, userId: string): void {
    const roomMembers = rooms.get(tripId);
    if (!roomMembers) return;

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

  /**
   * Diagnostic utility to verify room density during development testing.
   */
  getActiveCount(tripId: string): number {
    return rooms.get(tripId)?.size ?? 0;
  },
};
