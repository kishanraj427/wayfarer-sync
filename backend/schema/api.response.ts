import { z } from "zod";

export const apiSuccessSchema = <T extends z.ZodType>(dataSchema: T) =>
  z.object({
    success: z.literal(true),
    data: dataSchema,
  });

export const apiSuccessListSchema = <T extends z.ZodType>(dataSchema: T) =>
  z.object({
    success: z.literal(true),
    data: z.array(dataSchema),
  });

export const apiErrorSchema = z.object({
  success: z.literal(false),
  error: z.string(),
  details: z
    .array(
      z.object({
        message: z.string(),
        path: z.array(z.union([z.string(), z.number()])),
      }),
    )
    .optional(),
});

export const apiResponseSchema = <T extends z.ZodType>(dataSchema: T) =>
  z.union([apiSuccessSchema(dataSchema), apiErrorSchema]);

export type ApiSuccess<T> = { success: true; data: T };
export type ApiError = z.infer<typeof apiErrorSchema>;
export type ApiResponse<T> = ApiSuccess<T> | ApiError;
