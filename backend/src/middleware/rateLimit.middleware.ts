import rateLimit from "express-rate-limit";

/** Shared 15-minute rate-limit window, in milliseconds. */
const FIFTEEN_MINUTES_MS = 15 * 60 * 1000;
/** Rate-limit window for the general API limiter, in milliseconds. */
const ONE_MINUTE_MS = 60 * 1000;

/**
 * Raised from 100. Cluster A adds per-device traffic (a refresh every ~15 min
 * and a ws-ticket every ~10 min per active trip), and behind a proxy every
 * request shares one bucket until trust proxy is set. See spec §5.8.
 */
const GLOBAL_LIMIT_MAX = 1000;

/** Allows 10 requests per 15 minutes per IP to prevent brute-force attacks. */
const AUTH_LIMIT_MAX = 10;

/** Allows 60 requests per minute per IP. */
const API_LIMIT_MAX = 60;

/** Sized for legitimate refresh traffic: ~1 per 15 min per device, plus retries. */
const REFRESH_LIMIT_MAX = 20;

/** One ticket per socket connect plus one per ~10 min re-auth cycle. */
const TICKET_LIMIT_MAX = 60;

/**
 * Global rate limiter — applied to all routes.
 * Allows 1000 requests per 15 minutes per IP.
 */
export const globalLimiter = rateLimit({
  windowMs: FIFTEEN_MINUTES_MS,
  max: GLOBAL_LIMIT_MAX,
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
  windowMs: FIFTEEN_MINUTES_MS,
  max: AUTH_LIMIT_MAX,
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
  windowMs: ONE_MINUTE_MS,
  max: API_LIMIT_MAX,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many requests, please slow down.",
  },
});

/**
 * Rate limiter for POST /api/auth/refresh.
 * Deliberately NOT covered by authLimiter — see rejection note on
 * `router.post("/refresh", ...)` in auth.route.ts.
 */
export const refreshLimiter = rateLimit({
  windowMs: FIFTEEN_MINUTES_MS,
  max: REFRESH_LIMIT_MAX,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many refresh attempts, please try again later.",
  },
});

/**
 * Rate limiter for POST /api/auth/ws-ticket.
 * Deliberately NOT covered by authLimiter — see rejection note on
 * `router.post("/ws-ticket", ...)` in auth.route.ts.
 */
export const ticketLimiter = rateLimit({
  windowMs: FIFTEEN_MINUTES_MS,
  max: TICKET_LIMIT_MAX,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: {
    error: "Too many ticket requests, please slow down.",
  },
});
