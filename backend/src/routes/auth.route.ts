import { Router } from "express";
import { signup, login, getMe, refresh, exchange, wsTicket, logout } from "../controllers/auth.controller";
import { authenticate } from "../middleware/auth.middleware";
import { validate } from "../middleware/validate.middleware";
import { authLimiter, refreshLimiter, ticketLimiter } from "../middleware/rateLimit.middleware";
import { signupInputSchema, loginInputSchema } from "../../schema";

const router = Router();

// authLimiter (10/15min) must not cover /refresh or /ws-ticket — normal traffic there
// would exhaust it and 429 forever, breaking live tracking.
router.post("/signup", authLimiter, validate(signupInputSchema), signup);
router.post("/login", authLimiter, validate(loginInputSchema), login);
router.post("/refresh", refreshLimiter, refresh);
router.post("/exchange", refreshLimiter, exchange);
router.post("/ws-ticket", ticketLimiter, authenticate, wsTicket);
router.post("/logout", logout);
router.get("/me", authenticate, getMe);

export default router;
