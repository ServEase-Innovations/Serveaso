import {
    uploadOnCloudinary,
    deleteImageFromCloudinary
} from "../service/cloudinary.js";

import Image from '../models/Image.js';

export const uploadImageController = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                message: "Image file is required",
            });
        }
        console.log("file", req.file);
        const uploadImage = await uploadOnCloudinary(
            req.file.path,
            "mern-images"
        );
        const imageDoc = await Image.create({
           url: uploadImage.url, 
            public_id: uploadImage.public_id,
            folder: "mern-images",
        });
        return res.status(201).json({
            message: "Image uploaded & saved successfully",
            image: imageDoc,
        });
    }
  catch (error) {
  console.error("FULL ERROR 👉", error);   // 👈 this
  return res.status(500).json({
    message: error.message,
  });
}
};

export const deleteImageController = async (req, res) => {
  try {
    const { public_id } = req.body;

    // 1. delete from Cloudinary
    await deleteImageFromCloudinary(public_id);

    // 2. delete from MongoDB ✅ (THIS WAS MISSING)
    await Image.findOneAndDelete({ public_id });

    return res.status(200).json({
      message: "Image deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting image:", error);
    return res.status(500).json({
      message: "Error deleting image",
    });
  }
};

// export const deleteImageController = async (req, res) => {
//     try {
//         const { public_id } = req.body;
//         await deleteImageFromCloudinary(public_id);
//         return res.status(200).json({
//             message: "Image deleted successfully",
//         });
//     }
//     catch (error) {
//         console.error("Error deleting image:", error);
//         return res.status(500).json({
//             message: "Error deleting image",
//         });
//     }
// };
