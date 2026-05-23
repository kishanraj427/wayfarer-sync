import { Request, Response, NextFunction } from "express";
import { z } from "zod";

export const validate = (schema: z.ZodType) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      res
        .status(400)
        .json({ error: "Validation failed", details: result.error.issues });
      return;
    }
    next();
  };
};