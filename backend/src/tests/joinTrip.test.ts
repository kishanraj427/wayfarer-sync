import { test, expect, mock, describe, beforeEach } from "bun:test";

// Mock the Prisma client so the controller exercises the real service logic
// (trip lookup + membership create/read) against controllable data.
const mockTripFindFirst = mock((_args: any) => Promise.resolve<any>(null));
const mockMemberFindUnique = mock((_args: any) => Promise.resolve<any>(null));
const mockMemberCreate = mock((_args: any) => Promise.resolve<any>(null));

mock.module("../prisma", () => ({
  default: {
    trip: { findFirst: mockTripFindFirst },
    tripMember: {
      findUnique: mockMemberFindUnique,
      create: mockMemberCreate,
    },
  },
}));

import { joinTripById } from "../controllers/trip.controller";

// Valid RFC 4122 v4 UUIDs (version nibble 4, variant nibble 8) — z.uuid() is strict.
const TRIP_ID = "11111111-1111-4111-8111-111111111111";
const USER_ID = "22222222-2222-4222-8222-222222222222";

const makeReq = (id: string, userId?: string) =>
  ({ params: { id }, userId }) as any;

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

describe("POST /trip/:id/join handler", () => {
  beforeEach(() => {
    mockTripFindFirst.mockClear();
    mockMemberFindUnique.mockClear();
    mockMemberCreate.mockClear();
  });

  test("returns 404 when the request has no authenticated user", async () => {
    const res = makeRes();
    await joinTripById(makeReq(TRIP_ID), res);
    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test("returns 400 when the trip id is not a valid UUID", async () => {
    const res = makeRes();
    await joinTripById(makeReq("not-a-uuid", USER_ID), res);
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
    expect(mockTripFindFirst).not.toHaveBeenCalled();
  });

  test("returns 404 when the trip does not exist or is inactive", async () => {
    mockTripFindFirst.mockImplementation(() => Promise.resolve(null));
    const res = makeRes();
    await joinTripById(makeReq(TRIP_ID, USER_ID), res);
    expect(res.statusCode).toBe(404);
    expect(mockMemberCreate).not.toHaveBeenCalled();
  });

  test("returns 200 with alreadyMember=true and does not create a new membership", async () => {
    mockTripFindFirst.mockImplementation(() => Promise.resolve({ id: TRIP_ID }));
    const existing = {
      id: "member-1",
      tripId: TRIP_ID,
      userId: USER_ID,
      color: "#123456",
    };
    mockMemberFindUnique.mockImplementation(() => Promise.resolve(existing));

    const res = makeRes();
    await joinTripById(makeReq(TRIP_ID, USER_ID), res);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.alreadyMember).toBe(true);
    expect(res.body.data.member).toEqual(existing);
    expect(mockMemberCreate).not.toHaveBeenCalled();
  });

  test("returns 200 with alreadyMember=false and creates a membership for a new join", async () => {
    mockTripFindFirst.mockImplementation(() => Promise.resolve({ id: TRIP_ID }));
    mockMemberFindUnique.mockImplementation(() => Promise.resolve(null));
    const created = {
      id: "member-2",
      tripId: TRIP_ID,
      userId: USER_ID,
      color: "#abcdef",
    };
    mockMemberCreate.mockImplementation(() => Promise.resolve(created));

    const res = makeRes();
    await joinTripById(makeReq(TRIP_ID, USER_ID), res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data.alreadyMember).toBe(false);
    expect(res.body.data.member).toEqual(created);
    expect(mockMemberCreate).toHaveBeenCalledTimes(1);
  });
});
