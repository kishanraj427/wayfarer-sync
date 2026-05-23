import {
  apiSuccessSchema,
  apiErrorSchema,
  tripSchema,
  apiSuccessListSchema,
  pathPointBatchSchema,
  batchSuccessDataSchema,
  pathPointSchema,
  createTripInputSchema,
  updateTripInputSchema,
} from "../../../schema";
import { toSchema } from "../helpers";

const tripIdParam = {
  name: "id",
  in: "path",
  required: true,
  description: "The Trip UUID",
  schema: { type: "string", format: "uuid" },
};

export const tripPath = {
  "/api/trip": {
    get: {
      operationId: "listTrip",
      summary: "List trip",
      tags: ["Trip"],
      responses: {
        200: {
          description: "List Trip",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessListSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
    post: {
      operationId: "createTrip",
      summary: "Create a new trip",
      tags: ["Trip"],
      requestBody: {
        required: true,
        content: {
          "application/json": { schema: toSchema(createTripInputSchema) },
        },
      },
      responses: {
        201: {
          description: "Trip created",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/trip/{id}": {
    get: {
      operationId: "getTripById",
      summary: "Get trip",
      tags: ["Trip"],
      parameters: [tripIdParam],
      responses: {
        200: {
          description: "Get Trip",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
    put: {
      operationId: "updateTrip",
      summary: "Update an existing trip",
      tags: ["Trip"],
      parameters: [tripIdParam],
      requestBody: {
        required: true,
        content: {
          "application/json": { schema: toSchema(updateTripInputSchema) },
        },
      },
      responses: {
        200: {
          description: "Trip updated",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
    delete: {
      operationId: "deleteTrip",
      summary: "Delete trip",
      tags: ["Trip"],
      parameters: [tripIdParam],
      responses: {
        200: {
          description: "Trip deleted",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/trip/{id}/join": {
    post: {
      operationId: "joinTripById",
      summary: "Join trip",
      tags: ["Trip"],
      parameters: [tripIdParam],
      responses: {
        200: {
          description: "Joined trip successfully",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/trip/{id}/members": {
    get: {
      operationId: "getMembersById",
      summary: "Get Trip members by Id",
      tags: ["Trip"],
      parameters: [tripIdParam],
      responses: {
        200: {
          description: "Get Trip members by id",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(tripSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
  "/api/trip/{id}/paths/batch": {
    post: {
      operationId: "uploadPathBatch",
      summary: "Upload batch tracking path points collected offline",
      tags: ["Paths"],
      parameters: [
        {
          name: "id",
          in: "path",
          required: true,
          description: "The Trip UUID",
          schema: { type: "string", format: "uuid" },
        },
      ],
      requestBody: {
        required: true,
        content: {
          "application/json": { schema: toSchema(pathPointBatchSchema) },
        },
      },
      responses: {
        201: {
          description: "Batch points synchronized successfully",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessSchema(batchSuccessDataSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },

  "/api/trip/{id}/paths": {
    get: {
      operationId: "getPathsByTripId",
      summary: "Retrieve historical path lines for a trip",
      tags: ["Paths"],
      parameters: [
        {
          name: "id",
          in: "path",
          required: true,
          description: "The Trip UUID",
          schema: { type: "string", format: "uuid" },
        },
        {
          name: "since",
          in: "query",
          required: false,
          description: "Filter locations recorded after this ISO timestamp",
          schema: { type: "string", format: "date-time" },
        },
        {
          name: "userId",
          in: "query",
          required: false,
          description:
            "Filter path points to a specific user inside the trip group",
          schema: { type: "string", format: "uuid" },
        },
      ],
      responses: {
        200: {
          description: "Historical map traces fetched successfully",
          content: {
            "application/json": {
              schema: toSchema(apiSuccessListSchema(pathPointSchema)),
            },
          },
        },
        400: {
          description: "Validation error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
        500: {
          description: "Internal server error",
          content: {
            "application/json": { schema: toSchema(apiErrorSchema) },
          },
        },
      },
    },
  },
};
