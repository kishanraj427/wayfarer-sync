import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import swaggerUi from "swagger-ui-express";
import openApiSpec from "./openapi/index";
import authRoutes from "./routes/auth.route";
import tripRoutes from "./routes/trip.route";
import pathRoutes from "./routes/path.route";
import { createServer } from "http";
import { initWebSocketServer } from "./websocket";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use("/docs", swaggerUi.serve, swaggerUi.setup(openApiSpec));

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/auth", authRoutes);
app.use("/api/trip", tripRoutes);
app.use("/api/trip/:id/paths", pathRoutes);

// Wrap your Express application within an HTTP Server core instance
const server = createServer(app);

// Initialize the WebSocket handshake listener loops smoothly
initWebSocketServer(server);

server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export default app;
