import { Router } from "express";
import { signup, login, getMe } from "../controllers/auth.controller";
import { authenticate } from "../middleware/auth.middleware";
import { validate } from "../middleware/validate.middleware";
import {
  signupInputSchema,
  loginInputSchema,
} from "../../schema";

const router = Router();

router.post("/signup", validate(signupInputSchema), signup);
router.post("/login", validate(loginInputSchema), login);
router.get("/me", authenticate, getMe);

export default router;