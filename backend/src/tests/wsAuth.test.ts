import { test, expect, describe, beforeEach } from "bun:test";
import { roomManager } from "../services/websocket.manager";

const TRIP = "11111111-1111-4111-8111-111111111111";
const USER = "22222222-2222-4222-8222-222222222222";

const fakeSocket = () => {
  const s: any = { readyState: 1, closed: false, closeCode: undefined, sent: [] };
  s.close = (code?: number) => { s.closed = true; s.closeCode = code; };
  s.send = (m: string) => s.sent.push(m);
  return s;
};

describe("auth deadline tracking", () => {
  beforeEach(() => {
    // Module-level state persists across tests; clear it or a deadline from an earlier
    // test could leak in and mask what the R2 guard below is meant to prove.
    roomManager.clearAuthDeadline(TRIP, USER);
    const s = fakeSocket();
    roomManager.addUser(TRIP, USER, s);
    (globalThis as any).__sock = s;
  });

  test("a ticketed connection past its deadline is closed with 4001", () => {
    roomManager.setAuthDeadline(TRIP, USER, 1000);
    const closed = roomManager.sweepExpiredAuth(2000);
    expect(closed).toBe(1);
    expect((globalThis as any).__sock.closeCode).toBe(4001);
  });

  test("a ticketed connection inside its deadline survives", () => {
    roomManager.setAuthDeadline(TRIP, USER, 5000);
    expect(roomManager.sweepExpiredAuth(2000)).toBe(0);
    expect((globalThis as any).__sock.closed).toBe(false);
  });

  test("a legacy connection with NO deadline is never swept (R2)", () => {
    expect(roomManager.sweepExpiredAuth(Number.MAX_SAFE_INTEGER)).toBe(0);
    expect((globalThis as any).__sock.closed).toBe(false);
  });
});

// Distinct trip/user ids from the block above, isolated on purpose.
const EVICTION_TRIP = "33333333-3333-4333-8333-333333333333";
const EVICTION_USER = "44444444-4444-4444-8444-444444444444";

describe("auth deadline eviction (R2 regression)", () => {
  beforeEach(() => {
    roomManager.clearAuthDeadline(EVICTION_TRIP, EVICTION_USER);
  });

  // rooms/authDeadlines have no socket identity of their own, so a deadline armed for
  // an evicted (ticketed) socket must not fire against the new occupant of its slot.
  test("a legacy socket that evicts an expired-deadline ticketed socket is NOT swept with 4001", () => {
    const ticketedSocket = fakeSocket();
    roomManager.addUser(EVICTION_TRIP, EVICTION_USER, ticketedSocket);
    roomManager.setAuthDeadline(EVICTION_TRIP, EVICTION_USER, 1000); // already-expired deadline

    const legacySocket = fakeSocket();
    // Reconnect with no ticket/deadline; synchronously evicts ticketedSocket from the slot.
    roomManager.addUser(EVICTION_TRIP, EVICTION_USER, legacySocket);

    const closed = roomManager.sweepExpiredAuth(Number.MAX_SAFE_INTEGER);

    expect(legacySocket.closed).toBe(false);
    expect(legacySocket.closeCode).toBeUndefined();
    // closed may legitimately be 0 either way; the LEGACY socket must be untouched.
    expect(closed).toBe(0);
  });
});
