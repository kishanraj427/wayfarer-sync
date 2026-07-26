import { test, expect, describe } from "bun:test";
import { z } from "zod";
import { errorHandler } from "../middleware/error.middleware";

const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => ((res.statusCode = c), res);
  res.json = (b: any) => ((res.body = b), res);
  return res;
};

describe("errorHandler", () => {
  test("maps Prisma P2002 to 409 (fixes the signup race, bug #14)", () => {
    const res = makeRes();
    errorHandler({ code: "P2002" } as any, {} as any, res, () => {});
    expect(res.statusCode).toBe(409);
    expect(res.body.success).toBe(false);
  });

  test("maps Prisma P2025 to 404 (bug #21)", () => {
    const res = makeRes();
    errorHandler({ code: "P2025" } as any, {} as any, res, () => {});
    expect(res.statusCode).toBe(404);
  });

  test("maps ZodError to 400", () => {
    const res = makeRes();
    const err = z.object({ a: z.string() }).safeParse({}).error!;
    errorHandler(err as any, {} as any, res, () => {});
    expect(res.statusCode).toBe(400);
  });

  test("falls back to 500 for unknown errors", () => {
    const res = makeRes();
    errorHandler(new Error("boom") as any, {} as any, res, () => {});
    expect(res.statusCode).toBe(500);
  });

  test("always emits an `error` key — old clients read body['error'] (R2)", () => {
    const res = makeRes();
    errorHandler(new Error("boom") as any, {} as any, res, () => {});
    expect(typeof res.body.error).toBe("string");
  });
});
