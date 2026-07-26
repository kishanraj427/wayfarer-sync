import { Router } from "express";
import { authenticate } from "../middleware/auth.middleware";
import { requireTripMembership } from "../middleware/tripMembership.middleware";
import { validate } from "../middleware/validate.middleware";
import { createTripInputSchema, updateTripInputSchema } from "../../schema";
import {
  createTrip,
  deleteTripById,
  endTripById,
  getMembersById,
  getTripById,
  joinTripById,
  listTrip,
  updateTripById,
} from "@/controllers/trip.controller";

const tripRouter = Router();

tripRouter.get("/", authenticate, listTrip);
tripRouter.post("/", authenticate, validate(createTripInputSchema), createTrip);
tripRouter.get("/:id", authenticate, requireTripMembership, getTripById);
tripRouter.put("/:id", authenticate, requireTripMembership, validate(updateTripInputSchema), updateTripById);
tripRouter.delete("/:id", authenticate, requireTripMembership, deleteTripById);
tripRouter.post("/:id/join", authenticate, joinTripById); // NOT gated — not a member yet
tripRouter.post("/:id/end", authenticate, requireTripMembership, endTripById);
tripRouter.get("/:id/members", authenticate, requireTripMembership, getMembersById);

export default tripRouter;
