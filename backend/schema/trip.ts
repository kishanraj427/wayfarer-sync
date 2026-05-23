import z from "zod";
import { baseSchema } from "./base";
import { destinationSchema } from "./destination";

export const tripSchema = baseSchema.extend({
  title: z.string(),
  startedAt: z.iso.datetime(),
  endedAt: z.iso.datetime().optional().nullable(),
  destinations: z.array(destinationSchema).optional(),
});

export const createTripInputSchema = z.object({
  title: z.string().min(1),
  startedAt: z.iso.datetime(),
  endedAt: z.iso.datetime().optional().nullable(),
  destinations: z.array(destinationSchema).optional(),
});

export const updateTripInputSchema = z.object({
  title: z.string().min(1),
});

export type Trip = z.infer<typeof tripSchema>;
export type CreateTripInput = z.infer<typeof createTripInputSchema>;
export type UpdateTripInput = z.infer<typeof updateTripInputSchema>;
