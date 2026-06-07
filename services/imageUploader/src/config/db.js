import mongoose from "mongoose";

export function resolveMongoUri() {
  const uri = (
    process.env.MONGO_URI ||
    process.env.MONGODB_URI ||
    ""
  ).trim();
  return uri || null;
}

const connectDB = async () => {
  const uri = resolveMongoUri();
  if (!uri) {
    console.error(
      "❌ Set MONGO_URI or MONGODB_URI in Render/host env (MongoDB connection string)."
    );
    process.exit(1);
  }

  try {
    const conn = await mongoose.connect(uri);
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error("❌ DB connection error:", error.message);
    process.exit(1);
  }
};

export default connectDB;
