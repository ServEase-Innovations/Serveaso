import express from "express";
import uploadFile from "../middleware/multerFileUpload.js";
import multerErrorHandler from "../middleware/multerErrorHandler.js";
import { uploadFileController } from "../controller/file.controller.js";


const router = express.Router();
router.post(
  "/upload-file",   // pdf or image 
  uploadFile.single("file"),
  multerErrorHandler,
  uploadFileController
);

export default router;