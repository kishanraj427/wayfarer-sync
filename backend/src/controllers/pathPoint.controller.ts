import { Request, Response } from "express";
import * as pathService from "../services/pathPoint.service";
import { AuthRequest } from "@/middleware/auth.middleware";
import { pathPointBatchSchema, pathQuerySchema } from "../../schema";

export const uploadPathBatch = async (req: AuthRequest, res: Response) => {
  try {
    const { id: tripId } = req.params as { id: string };
    const userId = req.userId;

    if (!userId) {
      return res.status(404).json({
        message: "User not found",
        success: false,
      });
    }

    // Validate the raw request body array through your Zod configuration wrapper
    const parseResult = pathPointBatchSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        message: "Validation failed",
        details: parseResult.error.issues.map((e) => ({
          message: e.message,
          path: e.path,
        })),
      });
    }

    // Map contextual parameters to your payload securely
    const pointsData = parseResult.data.points.map((pt) => ({
      ...pt,
      tripId,
      userId,
    }));

    const result = await pathService.ingestPathBatch(pointsData);

    res.status(201).json({
      data: { count: result.count },
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to upload path batch data",
      success: false,
    });
  }
};

export const getPathsByTripId = async (req: Request, res: Response) => {
  try {
    const { id: tripId } = req.params as { id: string };

    // Parse safe query strings
    const queryParse = pathQuerySchema.safeParse(req.query);
    const queryData = queryParse.success ? queryParse.data : {};

    const paths = await pathService.getTripPaths(tripId, {
      userId: queryData.userId,
      since: queryData.since ? new Date(queryData.since) : undefined,
    });

    res.status(200).json({
      data: paths,
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch map tracks",
      success: false,
    });
  }
};
