import { Router } from "express";
import { authenticate } from "../middleware/auth.middleware";
import { validate } from "../middleware/validate.middleware";
import { createTripInputSchema, updateTripInputSchema } from "../../schema";
import {
  createTrip,
  deleteTripById,
  getMembersById,
  getTripById,
  joinTripById,
  listTrip,
  updateTripById,
} from "@/controllers/trip.controller";

const tripRouter = Router();

tripRouter.get("/", authenticate, listTrip);
tripRouter.post("/", authenticate, validate(createTripInputSchema), createTrip);
tripRouter.get("/:id", authenticate, getTripById);
tripRouter.put("/:id", authenticate, validate(updateTripInputSchema), updateTripById);
tripRouter.delete("/:id", authenticate, deleteTripById);
tripRouter.post("/:id/join", authenticate, joinTripById);
tripRouter.get("/:id/members", authenticate, getMembersById);

export default tripRouter;
