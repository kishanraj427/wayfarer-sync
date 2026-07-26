import { Request, Response } from "express";
import z from "zod";
import * as tripService from "../services/trip.service";
import { AuthRequest } from "@/middleware/auth.middleware";

export const listTrip = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return res.status(404).json({ message: "User not found", success: false });
    }
    const tripList = await tripService.listTrip(userId);

    res.status(200).json({
      data: tripList,
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch trips",
      success: false,
    });
  }
};

export const createTrip = async (req: AuthRequest, res: Response) => {
  try {
    const { title, startedAt, endedAt, destinations = [] } = req.body;
    const userId = req.userId;
    if (!userId) {
      return res.status(404).json({
        message: "User not found",
        success: false,
      });
    }
    const trip = await tripService.createTrip(
      userId,
      {
        title,
        startedAt: new Date(startedAt),
        endedAt: endedAt ? new Date(endedAt) : undefined,
      },
      destinations,
    );

    res.status(201).json({
      data: trip,
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to create trip",
      success: false,
    });
  }
};

export const getTripById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params as { id: string };

    const trip = await tripService.getTripById(id);

    if (!trip) {
      return res.status(404).json({
        message: "Trip not found",
        success: false,
      });
    }

    res.status(200).json({
      data: trip,
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch trip",
      success: false,
    });
  }
};

export const updateTripById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    const { title } = req.body;

    const trip = await tripService.updateTripById(id, {
      title,
    });

    res.status(200).json({
      data: trip,
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to update trip",
      success: false,
    });
  }
};

export const deleteTripById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params as { id: string };

    const trip = await tripService.deleteTripById(id);

    res.status(200).json({
      data: trip,
      success: true,
      message: "Trip deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to delete trip",
      success: false,
    });
  }
};

export const joinTripById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    const userId = req.userId;

    if (!userId) {
      return res.status(404).json({
        message: "User not found",
        success: false,
      });
    }

    const parsedTripId = z.uuid().safeParse(id);
    if (!parsedTripId.success) {
      return res.status(400).json({
        message: "Trip ID must be a valid UUID",
        success: false,
      });
    }

    const result = await tripService.joinTripById(parsedTripId.data, userId);

    if (!result) {
      return res.status(404).json({
        message: "Trip not found or no longer active",
        success: false,
      });
    }

    res.status(200).json({
      data: { member: result.member, alreadyMember: result.alreadyMember },
      success: true,
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to join trip",
      success: false,
    });
  }
};

export const getMembersById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    const members = await tripService.getTripMembers(id);
    res.json({ success: true, data: members });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch trip members",
      success: false,
    });
  }
};

export const endTripById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    const userId = req.userId;
    if (!userId) {
      return res.status(404).json({ message: "User not found", success: false });
    }
    const parsedTripId = z.uuid().safeParse(id);
    if (!parsedTripId.success) {
      return res.status(400).json({
        message: "Trip ID must be a valid UUID",
        success: false,
      });
    }
    const trip = await tripService.endTripById(parsedTripId.data);
    if (!trip) {
      return res.status(404).json({
        message: "Trip not found or you are not a member",
        success: false,
      });
    }
    res.status(200).json({ data: trip, success: true });
  } catch (error) {
    res.status(500).json({ message: "Failed to end trip", success: false });
  }
};
