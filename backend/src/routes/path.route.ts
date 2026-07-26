import { Router } from "express";
import { authenticate } from "../middleware/auth.middleware";
import { requireTripMembership } from "../middleware/tripMembership.middleware";
import {
  uploadPathBatch,
  getPathsByTripId,
} from "@/controllers/pathPoint.controller";

const pathRouter = Router({ mergeParams: true }); // preserves :id wrapper from root parameters

pathRouter.post("/batch", authenticate, requireTripMembership, uploadPathBatch);
pathRouter.get("/", authenticate, requireTripMembership, getPathsByTripId);

export default pathRouter;
