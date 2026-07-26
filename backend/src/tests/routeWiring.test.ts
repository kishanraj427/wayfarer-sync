import { test, expect, describe } from "bun:test";

process.env.JWT_SECRET ??= "test-access-secret";
process.env.JWT_REFRESH_SECRET ??= "r".repeat(32);
process.env.DATABASE_URL ??= "postgresql://u:p@localhost:5433/db";

const tripRouter = (await import("../routes/trip.route")).default;
const pathRouter = (await import("../routes/path.route")).default;

/** Bug #2: five trip endpoints skipped membership checks, letting any user read any trip's GPS history. Asserts the assembled router stack itself, since handler-level tests wouldn't catch a reordered/dropped middleware. */
const MEMBERSHIP = "requireTripMembership";
const AUTH = "authenticate";

const stackFor = (router: any, method: string, path: string): string[] => {
  const layer = router.stack.find(
    (l: any) => l.route?.path === path && l.route?.methods?.[method],
  );
  if (!layer) throw new Error(`route not found: ${method.toUpperCase()} ${path}`);
  return layer.route.stack.map((s: any) => s.handle.name);
};

describe("trip router middleware wiring (bug #2 regression guard)", () => {
  const gated: Array<[string, string]> = [
    ["get", "/:id"],
    ["put", "/:id"],
    ["delete", "/:id"],
    ["post", "/:id/end"],
    ["get", "/:id/members"],
  ];

  for (const [method, path] of gated) {
    test(`${method.toUpperCase()} ${path} enforces membership`, () => {
      const stack = stackFor(tripRouter, method, path);
      expect(stack).toContain(MEMBERSHIP);
      // Order matters: membership reads req.userId, which authenticate sets.
      expect(stack.indexOf(AUTH)).toBeLessThan(stack.indexOf(MEMBERSHIP));
    });
  }

  test("POST /:id/join is deliberately NOT membership-gated", () => {
    const stack = stackFor(tripRouter, "post", "/:id/join");
    expect(stack).toContain(AUTH);
    expect(stack).not.toContain(MEMBERSHIP);
  });

  test("collection routes are not membership-gated", () => {
    expect(stackFor(tripRouter, "get", "/")).not.toContain(MEMBERSHIP);
    expect(stackFor(tripRouter, "post", "/")).not.toContain(MEMBERSHIP);
  });
});

describe("path router middleware wiring (GPS history disclosure)", () => {
  test("POST /batch enforces membership after authenticate", () => {
    const stack = stackFor(pathRouter, "post", "/batch");
    expect(stack).toContain(MEMBERSHIP);
    expect(stack.indexOf(AUTH)).toBeLessThan(stack.indexOf(MEMBERSHIP));
  });

  test("GET / enforces membership after authenticate", () => {
    const stack = stackFor(pathRouter, "get", "/");
    expect(stack).toContain(MEMBERSHIP);
    expect(stack.indexOf(AUTH)).toBeLessThan(stack.indexOf(MEMBERSHIP));
  });

  test("mergeParams is enabled — without it req.params.id is undefined and every member gets a 400", () => {
    expect((pathRouter as any).mergeParams).toBe(true);
  });
});
