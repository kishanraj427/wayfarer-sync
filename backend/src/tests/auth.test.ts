import { test, expect, mock, describe, beforeEach } from "bun:test";

// Hermetic env preamble; generateToken() calls the real jsonwebtoken.sign, so a valid secret must exist.
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";
process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);

const mockUserFindUnique = mock((_args: any) => Promise.resolve<any>(null));
const mockUserCreate = mock((_args: any) => Promise.resolve<any>(null));

mock.module("../prisma", () => ({
  default: {
    user: { findUnique: mockUserFindUnique, create: mockUserCreate },
  },
}));

// Avoid a real bcrypt hash dependency in the controller path.
mock.module("bcryptjs", () => ({
  default: { hash: (value: string) => Promise.resolve(`hashed:${value}`) },
}));

// jsonwebtoken is intentionally NOT mocked: mock.module() leaks across files in Bun and
// can't be reliably restored, so real jwt.sign is used with the hermetic secret above.

import { signup } from "../controllers/auth.controller";

const USER_ID = "22222222-2222-4222-8222-222222222222";

const makeReq = (body: any) => ({ body }) as any;
const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (code: number) => ((res.statusCode = code), res);
  res.json = (body: any) => ((res.body = body), res);
  return res;
};

const validBody = {
  email: "kunal@essentia.dev",
  password: "secret123",
  firstName: "Kunal",
  lastName: "Sharma",
};

describe("signup", () => {
  beforeEach(() => {
    mockUserFindUnique.mockReset();
    mockUserCreate.mockReset();
    mockUserFindUnique.mockResolvedValue(null);
    mockUserCreate.mockImplementation((args: any) =>
      Promise.resolve({
        id: USER_ID,
        email: args.data.email,
        firstName: args.data.firstName,
        lastName: args.data.lastName,
        lastLoginAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        deletedAt: null,
      }),
    );
  });

  test("stores and echoes first/last name", async () => {
    const res = makeRes();
    await signup(makeReq(validBody), res);
    expect(res.statusCode).toBe(201);
    expect(mockUserCreate.mock.calls[0][0].data.firstName).toBe("Kunal");
    expect(res.body.user.firstName).toBe("Kunal");
    expect(res.body.user.lastName).toBe("Sharma");
  });

  test("rejects a blank name with 400", async () => {
    const res = makeRes();
    await signup(makeReq({ ...validBody, firstName: "   " }), res);
    expect(res.statusCode).toBe(400);
  });

  test("rejects an emoji name with 400", async () => {
    const res = makeRes();
    await signup(makeReq({ ...validBody, lastName: "Sharma😀" }), res);
    expect(res.statusCode).toBe(400);
  });
});
