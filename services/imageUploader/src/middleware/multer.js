import multer from "multer";
import fs from "fs";
import path from "path";
import imageFileFilter from "../utils/multerFileFilter.js";

const uploadDir = path.resolve("src/upload");

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + "-" + file.originalname);
  },
});

const uploadImageMulter = multer({
  storage,
  fileFilter: imageFileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024,
  },
});

export default uploadImageMulter;