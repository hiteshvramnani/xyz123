import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import fs from 'fs';
import { env } from './config/env';
import { errorHandler } from './middleware/error-handler';
import { apiLimiter } from './middleware/rate-limit';
import authRoutes from './modules/auth/auth.routes';
import trailRoutes from './modules/trail/trail.routes';
import submissionRoutes from './modules/submission/submission.routes';
import mediaRoutes from './modules/media/media.routes';
import searchRoutes from './modules/search/search.routes';
import meRoutes from './modules/me/me.routes';
import userRoutes from './modules/user/user.routes';
import evidenceRoutes from './modules/evidence/evidence.routes';
import path from 'path';

const app = express();

// Security & middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan(env.NODE_ENV === 'development' ? 'dev' : 'combined'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Handle local uploads (GET to serve, PUT to write) when FILE_STORAGE=local
if (process.env.FILE_STORAGE === 'local') {
  const uploadBase = path.join(__dirname, '../uploads');

  // PUT: write file from the upload
  app.put('/uploads/*', async (req, res) => {
    const relativePath = req.params[0];
    const filePath = path.join(uploadBase, relativePath);

    // Security: prevent path traversal
    if (!path.resolve(filePath).startsWith(path.resolve(uploadBase))) {
      return res.status(403).send('Forbidden');
    }

    // Ensure directory exists
    fs.mkdirSync(path.dirname(filePath), { recursive: true });

    const writeStream = fs.createWriteStream(filePath);
    req.pipe(writeStream);
    writeStream.on('finish', () => res.status(200).send('OK'));
    writeStream.on('error', () => res.status(500).send('Failed'));
  });

  // GET: serve the file
  app.use('/uploads', express.static(uploadBase));
}

// Global rate limiting
app.use('/api/', apiLimiter);

// API routes
const prefix = `/api/${env.API_VERSION}`;

// Auth + user management (login is public, rest is admin-only)
app.use(`${prefix}/auth`, authRoutes);
app.use(`${prefix}/auth`, userRoutes);

// Trail management
app.use(`${prefix}/trails`, trailRoutes);

// Submissions router handles submissions, threads, and inline media uploads
app.use(`${prefix}/submissions`, submissionRoutes);

// Standalone media endpoints (download, delete by media id)
app.use(`${prefix}/media`, mediaRoutes);
app.use(`${prefix}/search`, searchRoutes);

// User portal endpoints
app.use(`${prefix}/me`, meRoutes);

// Public evidence submission (no auth required)
app.use(`${prefix}/evidence`, evidenceRoutes);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Catch-all 404 — return JSON instead of HTML
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' } });
});

// Error handler (must be last)
app.use(errorHandler);

export default app;
