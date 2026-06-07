# Image uploader

Express service for image/file uploads to **Cloudinary** with metadata in **MongoDB**.

## Local

```bash
cp .env.example .env
# Set MONGO_URI, CLOUDINARY_*
npm install
npm run dev
```

## Render

| Setting | Value |
|---------|--------|
| **Start command** | `npm start` (not `npm run dev`) |
| **Build command** | `npm install` |

### Required env vars

| Variable | Description |
|----------|-------------|
| `MONGO_URI` or `MONGODB_URI` | MongoDB connection string |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | Cloudinary API secret |
| `CORS_ORIGINS` | Required when `NODE_ENV=production` |
| `NODE_ENV` | `production` |
| `PORT` | Set by Render automatically |

Health: `GET /health`, `GET /ready`
