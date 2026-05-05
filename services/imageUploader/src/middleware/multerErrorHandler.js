const multerErrorHandler = (err, req, res, next) => {
  if (err) {
    return res.status(400).json({
      message: err.message || "File upload error",
    });
  }
  next();
};

export default multerErrorHandler;