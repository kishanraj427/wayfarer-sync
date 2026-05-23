import { z } from "zod";

export const toSchema = (schema: z.ZodType) => z.toJSONSchema(schema);