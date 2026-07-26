import { test, expect, mock, describe, beforeEach } from "bun:test";

const mockMemberFindUnique = mock((_a: any) => Promise.resolve<any>(null));

// mock.module() replacements persist process-wide in Bun, affecting every
// suite loaded afterward. Several existing test files mock "../prisma" with a
// user-shaped stub, so this stub is kept a SUPERSET (adds `user`) even though
// this file only ever exercises `tripMember.findUnique`, to avoid breaking
// suites that load later and expect `user.*` to exist.
const mockUserFindUnique = mock((_a: any) => Promise.resolve<any>(null));
const mockUserCreate = mock((_a: any) => Promise.resolve<any>(null));

mock.module("../prisma", () => ({
  default: {
    tripMember: { findUnique: mockMemberFindUnique },
    user: { findUnique: mockUserFindUnique, create: mockUserCreate },
  },
}));

const { requireTripMembership } = await import("../middleware/tripMembership.middleware");

const USER_ID = "22222222-2222-4222-8222-222222222222";
const TRIP_ID = "11111111-1111-4111-8111-111111111111";

const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => ((res.statusCode = c), res);
  res.json = (b: any) => ((res.body = b), res);
  return res;
};
const run = async (params: any, userId?: string) => {
  const req: any = { params, userId };
  const res = makeRes();
  let nexted = false;
  await requireTripMembership(req, res, () => { nexted = true; });
  return { req, res, nexted };
};

describe("requireTripMembership", () => {
  beforeEach(() => mockMemberFindUnique.mockClear());

  test("calls next and attaches tripMember for a member", async () => {
    const member = { id: "m1", color: "#fff", trip: { deletedAt: null } };
    mockMemberFindUnique.mockImplementation(() => Promise.resolve(member));
    const { req, nexted } = await run({ id: TRIP_ID }, USER_ID);
    expect(nexted).toBe(true);
    expect(req.tripMember).toEqual(member);
  });

  test("returns 404 NOT 403 for a non-member (no existence leak)", async () => {
    mockMemberFindUnique.mockImplementation(() => Promise.resolve(null));
    const { res, nexted } = await run({ id: TRIP_ID }, USER_ID);
    expect(res.statusCode).toBe(404);
    expect(nexted).toBe(false);
  });

  test("returns 404 for a soft-deleted trip", async () => {
    mockMemberFindUnique.mockImplementation(() =>
      Promise.resolve({ id: "m1", trip: { deletedAt: new Date() } }));
    const { res } = await run({ id: TRIP_ID }, USER_ID);
    expect(res.statusCode).toBe(404);
  });

  test("returns 400 for a malformed UUID without querying the database", async () => {
    const { res } = await run({ id: "not-a-uuid" }, USER_ID);
    expect(res.statusCode).toBe(400);
    expect(mockMemberFindUnique).not.toHaveBeenCalled();
  });

  test("returns 401 when unauthenticated", async () => {
    const { res } = await run({ id: TRIP_ID }, undefined);
    expect(res.statusCode).toBe(401);
  });

  test("allows an ENDED but not deleted trip (bug #12 is Cluster C, not here)", async () => {
    mockMemberFindUnique.mockImplementation(() =>
      Promise.resolve({ id: "m1", trip: { deletedAt: null } }));
    const { nexted } = await run({ id: TRIP_ID }, USER_ID);
    expect(nexted).toBe(true);
  });
});
