import { test, expect, describe } from "bun:test";
import { pathPointBatchSchema } from "../../schema";

describe("pathPointBatchSchema (client input shape)", () => {
  const validPoint = {
    latitude: 37.7749,
    longitude: -122.4194,
    timestamp: new Date().toISOString(),
    accuracy: 5.0,
  };

  test("accepts the mobile payload with no id/tripId/userId", () => {
    const result = pathPointBatchSchema.safeParse({ points: [validPoint] });
    expect(result.success).toBe(true);
  });

  test("accepts a point without accuracy", () => {
    const { accuracy, ...pointWithoutAccuracy } = validPoint;
    const result = pathPointBatchSchema.safeParse({ points: [pointWithoutAccuracy] });
    expect(result.success).toBe(true);
  });

  test("rejects latitude out of bounds", () => {
    const result = pathPointBatchSchema.safeParse({
      points: [{ ...validPoint, latitude: 120.5 }],
    });
    expect(result.success).toBe(false);
  });

  test("rejects longitude out of bounds", () => {
    const result = pathPointBatchSchema.safeParse({
      points: [{ ...validPoint, longitude: 200 }],
    });
    expect(result.success).toBe(false);
  });

  test("rejects a malformed timestamp", () => {
    const result = pathPointBatchSchema.safeParse({
      points: [{ ...validPoint, timestamp: "not-a-date" }],
    });
    expect(result.success).toBe(false);
  });

  test("rejects an empty points array", () => {
    const result = pathPointBatchSchema.safeParse({ points: [] });
    expect(result.success).toBe(false);
  });

  test("rejects more than 200 points", () => {
    const points = Array.from({ length: 201 }, () => validPoint);
    const result = pathPointBatchSchema.safeParse({ points });
    expect(result.success).toBe(false);
  });
});
