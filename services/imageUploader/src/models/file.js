import mongoose from "mongoose";

const fileSchema = new mongoose.Schema(
  {
    url: {
      type: String,
      required: true,
    },
    public_id: {
      type: String,
      required: true,
    },
    folder: {
      type: String,
      default: "mern-files",
    },
    fileType: {
      type: String,
      enum: ["image", "pdf"],
    },
  },
  { timestamps: true }
);

const File = mongoose.model("File", fileSchema);

export default File;