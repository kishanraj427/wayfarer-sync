import { Router } from "express";
import { authenticate } from "../middleware/auth.middleware";
import {
  uploadPathBatch,
  getPathsByTripId,
} from "@/controllers/pathPoint.controller";

const pathRouter = Router({ mergeParams: true }); // preserves :id wrapper from root parameters

pathRouter.post("/batch", authenticate, uploadPathBatch);
pathRouter.get("/", authenticate, getPathsByTripId);

export default pathRouter;
