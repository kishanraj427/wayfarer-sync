import rateLimit from "express-rate-limit";

/**
 * Global rate limiter — applied to all routes.
 * Allows 100 requests per 15 minutes per IP.
 */
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: "draft-7", // Return `RateLimit-*` headers
  legacyHeaders: false,
  message: {
    error: "Too many requests, please try again later.",
  },
});

/**
 * Strict rate limiter for auth endpoints (login / register).
 * Allows 10 requests per 15 minutes per IP to prevent brute-force attacks.
 */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many authentication attempts, please try again later.",
  },
});

/**
 * Moderate rate limiter for general API routes (trips, paths).
 * Allows 60 requests per minute per IP.
 */
export const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 60,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many requests, please slow down.",
  },
});
