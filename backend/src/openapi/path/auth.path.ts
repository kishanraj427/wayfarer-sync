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
};