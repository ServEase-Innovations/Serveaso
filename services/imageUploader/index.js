import express from "express";
import dotenv from "dotenv";
import swaggerUi from "swagger-ui-express";
import mongoose from "mongoose";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, `.env.${process.env.NODE_ENV || "development"}`) });
dotenv.config({ path: path.join(__dirname, ".env") });

import connectDB from "./src/config/db.js";
import { corsMiddleware } from "./src/middleware/corsMiddleware.js";
import { assertCorsOriginsProduction } from "./src/lib/corsOrigins.js";
import imageRoutes from "./src/routes/image.routes.js";
import fileRoutes from "./src/routes/file.routes.js";
import { swaggerSpec } from "./src/config/swaggerSpec.js";
import { v2 as cloudinary } from "cloudinary";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

if (process.env.NODE_ENV === "production") {
  assertCorsOriginsProduction();
}

const app = express();
app.use(corsMiddleware);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: true }));
app.get("/api-docs.json", (_req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(swaggerSpec);
});

app.use("/api/images", imageRoutes);
app.use("/api/files", fileRoutes);

app.get("/health", (_req, res) => {
  res.status(200).json({
    status: "ok",
    service: "image-uploader",
    uptime: process.uptime(),
  });
});

app.get("/ready", (_req, res) => {
  const ready = mongoose.connection.readyState === 1;
  res.status(ready ? 200 : 503).json({
    status: ready ? "ready" : "not_ready",
    service: "image-uploader",
  });
});

app.get("/", (_req, res) => {
  res.send(
    "Server running 🚀 — API docs: <a href=\"/api-docs\">/api-docs</a>"
  );
});

const PORT = Number(process.env.PORT) || 3000;

async function startServer() {
  await connectDB();
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Image uploader listening on port ${PORT}`);
  });
}

startServer().catch((err) => {
  console.error("❌ Failed to start:", err?.message || err);
  process.exit(1);
});
