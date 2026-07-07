import { test, expect, describe } from "bun:test";
import { WebSocket } from "ws";
import { roomManager } from "../services/websocket.manager";

// A minimal stand-in for a live ws connection: it reports itself OPEN and
// records every frame the room manager sends to it.
const createFakeSocket = () => {
  const sentList: string[] = [];
  return {
    readyState: WebSocket.OPEN,
    sentList,
    send(message: string) {
      sentList.push(message);
    },
    close() {},
  } as any;
};

describe("roomManager reconnect membership", () => {
  // Regression for the reconnect race. addUser replaces a user's socket
  // synchronously on reconnect; the OLD socket's close handler fires a tick
  // later and calls removeUser. Without the compare-and-delete guard, that
  // deletes the entry now pointing at the NEW socket, evicting a live user so
  // they stop receiving other members' broadcasts.
  test("old socket's close does not evict the reconnected socket", () => {
    const tripId = "trip-reconnect";
    const viewerId = "viewer";
    const senderId = "sender";

    const oldSocket = createFakeSocket();
    const newSocket = createFakeSocket();
    const senderSocket = createFakeSocket();

    roomManager.addUser(tripId, viewerId, oldSocket);
    roomManager.addUser(tripId, viewerId, newSocket); // reconnect replaces old
    roomManager.addUser(tripId, senderId, senderSocket);

    // The old socket's delayed close handler runs after the reconnect.
    roomManager.removeUser(tripId, viewerId, oldSocket);

    // A peer broadcasts — the reconnected viewer must still receive it.
    roomManager.broadcastToRoom(tripId, senderId, "member_location", {
      userId: senderId,
    });

    expect(newSocket.sentList.length).toBe(1);
    expect(oldSocket.sentList.length).toBe(0);
  });

  test("a socket's own close still evicts it", () => {
    const tripId = "trip-normal-close";
    const viewerId = "viewer";

    const socket = createFakeSocket();
    roomManager.addUser(tripId, viewerId, socket);
    roomManager.removeUser(tripId, viewerId, socket);

    // No live socket remains, so a broadcast reaches no one.
    roomManager.broadcastToRoom(tripId, "someone-else", "member_location", {
      userId: "someone-else",
    });

    expect(socket.sentList.length).toBe(0);
    expect(roomManager.getActiveCount(tripId)).toBe(0);
  });
});
