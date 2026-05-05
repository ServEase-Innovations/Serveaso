import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import swaggerUi from "swagger-ui-express";

dotenv.config({ path: "./.env" });
import connectDB from "./src/config/db.js";
import imageRoutes from "./src/routes/image.routes.js";
import fileRoutes from "./src/routes/file.routes.js";
import { swaggerSpec } from "./src/config/swaggerSpec.js";
import { v2 as cloudinary } from "cloudinary";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

const app = express();
connectDB();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: true }));
app.get("/api-docs.json", (_req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(swaggerSpec);
});

app.use("/api/images", imageRoutes);
app.use("/api/files", fileRoutes);

app.get("/", (req, res) => {
  res.send(
    "Server running 🚀 — API docs: <a href=\"/api-docs\">/api-docs</a>"
  );
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running at: http://localhost:${PORT}`);
});