import express from "express";
import {
    uploadImageController,
    deleteImageController,
} from "../controller/upload.controller.js";
import upload from "../middleware/multer.js";
import multerErrorHandler from "../middleware/multerErrorHandler.js";


const router = express.Router();

router.post("/upload", upload.single("image"), multerErrorHandler, uploadImageController);
router.delete("/delete", deleteImageController);

export default router;