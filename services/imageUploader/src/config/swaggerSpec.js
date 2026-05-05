/**
 * OpenAPI 3 spec for Swagger UI (/api-docs)
 */
export const swaggerSpec = {
  openapi: "3.0.3",
  info: {
    title: "Image Uploader Service",
    version: "1.0.0",
    description:
      "Upload images or files (images/PDFs) to Cloudinary and persist metadata in MongoDB.",
  },
  tags: [
    { name: "Images", description: "Image upload and delete" },
    { name: "Files", description: "Image or PDF upload" },
    { name: "Health", description: "Service health" },
  ],
  paths: {
    "/": {
      get: {
        tags: ["Health"],
        summary: "Health check",
        responses: {
          "200": {
            description: "Plain text OK",
            content: {
              "text/plain": {
                schema: { type: "string", example: "Server running 🚀" },
              },
            },
          },
        },
      },
    },
    "/api/images/upload": {
      post: {
        tags: ["Images"],
        summary: "Upload an image",
        description:
          "Multipart form with field `image`. Max size 5MB. Saved to Cloudinary folder `mern-images`.",
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                required: ["image"],
                properties: {
                  image: {
                    type: "string",
                    format: "binary",
                    description: "Image file",
                  },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    message: { type: "string" },
                    image: { type: "object", additionalProperties: true },
                  },
                },
              },
            },
          },
          "400": {
            description: "Missing file",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { message: { type: "string" } },
                },
              },
            },
          },
          "500": { description: "Server error" },
        },
      },
    },
    "/api/images/delete": {
      delete: {
        tags: ["Images"],
        summary: "Delete an image by Cloudinary public_id",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["public_id"],
                properties: {
                  public_id: {
                    type: "string",
                    description: "Cloudinary public_id",
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Deleted",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { message: { type: "string" } },
                },
              },
            },
          },
          "500": { description: "Server error" },
        },
      },
    },
    "/api/files/upload-file": {
      post: {
        tags: ["Files"],
        summary: "Upload an image or PDF",
        description:
          "Multipart form with field `file`. Images or application/pdf. Max size 10MB. Saved to Cloudinary folder `mern-files`.",
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                required: ["file"],
                properties: {
                  file: {
                    type: "string",
                    format: "binary",
                    description: "Image or PDF file",
                  },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    message: { type: "string" },
                    file: { type: "object", additionalProperties: true },
                  },
                },
              },
            },
          },
          "400": {
            description: "Missing file",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { message: { type: "string" } },
                },
              },
            },
          },
          "500": { description: "Server error" },
        },
      },
    },
  },
};
