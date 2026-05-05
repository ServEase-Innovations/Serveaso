import multer from "multer";
import imageFileFilter from "../utils/multerFileFilter.js";

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "src/upload/");   // ✅ correct
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