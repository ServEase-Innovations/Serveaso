import { v2 as cloudinary } from "cloudinary";
import fs from "fs";

export const uploadOnCloudinary = async(
    localFilePath,
    folder = "uploads"
) => {
    if (!localFilePath) throw new Error("Local file path is required");
    try {
        const uploadResult = await cloudinary.uploader.upload(localFilePath, {
            folder,
            resource_type: "auto",
        });
        
        await fs.promises.unlink(localFilePath);
        return {
            url: uploadResult.secure_url,
            public_id: uploadResult.public_id,
        };
    } catch (error) {
        if (localFilePath) {
            await fs.promises.unlink(localFilePath).catch(() => {});
        }
        throw error;
    }
};

export const deleteImageFromCloudinary = async(public_id) => {
    if (!public_id) throw new Error("Public ID is required for deletion");
    try {
        await cloudinary.uploader.destroy(public_id);
    } catch (error) {
        throw new Error(`Failed to delete image from Cloudinary: ${error.message}`);
    }
};