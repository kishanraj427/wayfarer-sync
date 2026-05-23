import z from "zod";

export const destinationSchema = z.object({
  name: z.string().min(1),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  order: z.number().int().optional(),
});

export type Destination = z.infer<typeof destinationSchema>;
