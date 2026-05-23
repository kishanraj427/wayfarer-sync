import { z } from "zod";

export const baseSchema = z.object({
  id: z.uuid().readonly(),
  createdAt: z.iso.datetime().readonly(),
  updatedAt: z.iso.datetime().readonly(),
  deletedAt: z.iso.datetime().optional().nullable().readonly(),
});

export type Base = z.infer<typeof baseSchema>;