import File from "../models/file.js";
import { uploadOnCloudinary } from "../service/cloudinary.js";

export const uploadFileController = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        message: "File is required",
      });
    }

    const uploadedFile = await uploadOnCloudinary(
      req.file.path,
      "mern-files"
    );

    // detect type
    const type = req.file.mimetype === "application/pdf" ? "pdf" : "image";

    const fileDoc = await File.create({
      url: uploadedFile.url,
      public_id: uploadedFile.public_id,
      folder: "mern-files",
      fileType: type,
    });

    return res.status(201).json({
      message: "File uploaded successfully",
      file: fileDoc,
    });
  } catch (error) {
    console.error("FULL ERROR 👉", error);
    return res.status(500).json({
      message: error.message,
    });
  }
};