import multer from "multer";

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "src/upload/");
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + "-" + file.originalname);
  },
});

const fileFilter = (req, file, cb) => {
  const isImage = file.mimetype.startsWith("image/");
  const isPDF = file.mimetype === "application/pdf";

  if (!isImage && !isPDF) {
    return cb(new Error("Only Image and PDF allowed"), false);
  }

  cb(null, true);
};

const uploadFile = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB (PDF bigger usually)
  },
});

export default uploadFile;