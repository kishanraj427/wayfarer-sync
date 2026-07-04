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

  test("returns 404 when the caller is not a member", async () => {
    mockMemberFindUnique.mockImplementation(() => Promise.resolve(null));
    const res = makeRes();
    await endTripById({ params: { id: TRIP_ID }, userId: USER_ID } as any, res);
    expect(res.statusCode).toBe(404);
    expect(mockTripUpdate).not.toHaveBeenCalled();
  });

  test("returns 404 when the trip is deleted", async () => {
    mockMemberFindUnique.mockImplementation(() =>
      Promise.resolve({ id: "m1", trip: { deletedAt: new Date() } }),
    );
    const res = makeRes();
    await endTripById({ params: { id: TRIP_ID }, userId: USER_ID } as any, res);
    expect(res.statusCode).toBe(404);
    expect(mockTripUpdate).not.toHaveBeenCalled();
  });

  test("sets endedAt and returns the updated trip for a member", async () => {
    mockMemberFindUnique.mockImplementation(() =>
      Promise.resolve({ id: "m1", trip: { deletedAt: null } }),
    );
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
