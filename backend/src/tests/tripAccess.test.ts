import { test, expect, mock, describe, beforeEach } from "bun:test";

const mockTripFindMany = mock((_args: any) => Promise.resolve<any>([]));
const mockTripUpdate = mock((_args: any) => Promise.resolve<any>(null));
const mockMemberFindUnique = mock((_args: any) => Promise.resolve<any>(null));

mock.module("../prisma", () => ({
  default: {
    trip: { findMany: mockTripFindMany, update: mockTripUpdate },
    tripMember: { findUnique: mockMemberFindUnique },
  },
}));

import { listTrip, endTripById } from "../controllers/trip.controller";

const USER_ID = "22222222-2222-4222-8222-222222222222";
const TRIP_ID = "11111111-1111-4111-8111-111111111111";

const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (code: number) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body: any) => {
    res.body = body;
    return res;
  };
  return res;
};

describe("GET /trip handler", () => {
  beforeEach(() => {
    mockTripFindMany.mockClear();
    mockTripUpdate.mockClear();
    mockMemberFindUnique.mockClear();
  });

  test("returns 404 without an authenticated user", async () => {
    const res = makeRes();
    await listTrip({} as any, res);
    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test("queries only trips the user is a member of, capped at 100", async () => {
    mockTripFindMany.mockImplementation(() => Promise.resolve([{ id: "t1" }]));
    const res = makeRes();
    await listTrip({ userId: USER_ID } as any, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data).toEqual([{ id: "t1" }]);
    const callArg = mockTripFindMany.mock.calls[0][0];
    expect(callArg.where.members.some.userId).toBe(USER_ID);
    expect(callArg.where.deletedAt).toBeNull();
    expect(callArg.take).toBe(100);
  });
});

describe("POST /trip/:id/end handler", () => {
  beforeEach(() => {
    mockTripFindMany.mockClear();
    mockTripUpdate.mockClear();
    mockMemberFindUnique.mockClear();
  });

  test("returns 400 for a non-UUID trip id", async () => {
    const res = makeRes();
    await endTripById({ params: { id: "nope" }, userId: USER_ID } as any, res);
    expect(res.statusCode).toBe(400);
    expect(mockMemberFindUnique).not.toHaveBeenCalled();
  });

  // Membership and deletedAt checks (404, not 403, for a non-member; 404 for
  // a soft-deleted trip) moved to requireTripMembership, which now runs
  // ahead of this handler on the route (backend/src/routes/trip.route.ts).
  // That behavior is exhaustively covered by
  // backend/src/tests/tripMembership.test.ts. The controller's endTripById
  // no longer performs its own membership lookup (trip.service.ts:129), so
  // those two 404 cases no longer apply at this layer.

  test("sets endedAt and returns the updated trip for a member", async () => {
    const updated = { id: TRIP_ID, endedAt: new Date().toISOString() };
    mockTripUpdate.mockImplementation(() => Promise.resolve(updated));

    const res = makeRes();
    await endTripById({ params: { id: TRIP_ID }, userId: USER_ID } as any, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data).toEqual(updated);
    const updateArg = mockTripUpdate.mock.calls[0][0];
    expect(updateArg.where.id).toBe(TRIP_ID);
    expect(updateArg.data.endedAt).toBeInstanceOf(Date);
  });
});
