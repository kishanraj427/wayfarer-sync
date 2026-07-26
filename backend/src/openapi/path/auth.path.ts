import {
  signupInputSchema,
  loginInputSchema,
  userSchema,
  authResponseSchema,
  apiSuccessSchema,
  apiErrorSchema,
} from "../../../schema";
import { toSchema } from "../helpers";

export const authPath = {
  "/api/auth/signup": {
    post: {
      operationId: "signup",
      summary: "Register a new user",
      tags: ["Auth"],
      requestBody: {
        required: true,
        content: {
          "application/json": { schema: toSchema(signupInputSchema) },
        },
      },
      responses: {
        201: {
          description: "User created",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(authResponseSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        409: {
          description: "Email already exists",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/auth/login": {
    post: {
      operationId: "login",
      summary: "Login with credentials",
      tags: ["Auth"],
      requestBody: {
        required: true,
        content: {
          "application/json": { schema: toSchema(loginInputSchema) },
        },
      },
      responses: {
        200: {
          description: "Login successful",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(authResponseSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        401: {
          description: "Invalid credentials",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/auth/me": {
    get: {
      operationId: "getCurrentUser",
      summary: "Get current user",
      tags: ["Auth"],
      security: [{ BearerAuth: [] }],
      responses: {
        200: {
          description: "Current user",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(userSchema)),
            },
          },
        },
        401: {
          description: "Unauthorized",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/auth/refresh": {
    post: {
      operationId: "refreshTokens",
      summary: "Exchange a refresh token for a new token pair (sliding rotation)",
      description:
        "Rotation is sliding: each successful call issues a NEW refresh token, so an " +
        "active user is never logged out by expiry. Responses are FLAT — they must never " +
        "gain a top-level `data` key, because the deployed mobile client reads `body['data']` " +
        "when present and the whole body otherwise.",
      tags: ["Auth"],
      requestBody: {
        required: true,
        content: {
          "application/json": {
            schema: {
              type: "object",
              required: ["refreshToken"],
              properties: { refreshToken: { type: "string" } },
            },
          },
        },
      },
      responses: {
        200: {
          description:
            "New token pair. Body carries `token` (7d legacy alias), `accessToken` (15m) and `refreshToken` (30d).",
        },
        401: {
          description:
            "Invalid or expired refresh token. Body carries `code: 'INVALID_REFRESH'`. " +
            "THIS IS A CONTRACT: that code is the ONLY signal that causes the mobile client " +
            "to clear its tokens and show the login screen. Never emit it for a transient or " +
            "server-side failure.",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        429: { description: "Rate limited (20 requests / 15 min)" },
      },
    },
  },
  "/api/auth/exchange": {
    post: {
      operationId: "exchangeLegacyToken",
      summary: "One-shot upgrade: swap a legacy access token for a token pair",
      description:
        "For installs upgraded in place from a release that had no refresh token. The client " +
        "holds an access token but no refresh token; this mints both without forcing a re-login. " +
        "Does not use the shared auth middleware: the bearer sent here is the client's only " +
        "credential, so a rejection is genuine session death rather than a transient failure.",
      tags: ["Auth"],
      security: [{ BearerAuth: [] }],
      responses: {
        200: { description: "New token pair" },
        401: {
          description:
            "The bearer token was missing, malformed, expired, or not an access token. " +
            "Body carries `code: 'INVALID_REFRESH'` — the client ends the session and shows " +
            "an explanation. A bare 401 here would be read as transient and strand the " +
            "install retrying forever.",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        429: { description: "Rate limited (20 requests / 15 min)" },
      },
    },
  },
  "/api/auth/ws-ticket": {
    post: {
      operationId: "createWsTicket",
      summary: "Mint a 30-second WebSocket ticket scoped to one trip",
      description:
        "The ticket is bound to the given tripId and is rejected at upgrade if presented for " +
        "any other trip. Clients re-auth an open socket every 10 minutes by sending an " +
        "`auth_refresh` message carrying a fresh ticket; the server closes sockets that have " +
        "not re-authed within 15 minutes using close code 4001.",
      tags: ["Auth"],
      security: [{ BearerAuth: [] }],
      requestBody: {
        required: true,
        content: {
          "application/json": {
            schema: {
              type: "object",
              required: ["tripId"],
              properties: { tripId: { type: "string", format: "uuid" } },
            },
          },
        },
      },
      responses: {
        200: { description: "Ticket minted. Body carries `ticket`." },
        400: {
          description: "tripId is missing or not a valid UUID",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        401: {
          description: "Not authenticated",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        429: { description: "Rate limited (60 requests / 15 min)" },
      },
    },
  },
  "/api/auth/logout": {
    post: {
      operationId: "logout",
      summary: "Client-side logout",
      description:
        "The token design is stateless, so there is nothing server-side to revoke and this " +
        "endpoint does not pretend otherwise. The client clears its own tokens. A refresh " +
        "token therefore stays redeemable until it expires.",
      tags: ["Auth"],
      responses: {
        200: { description: "Always succeeds" },
      },
    },
  },
};