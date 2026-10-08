import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  API_VERSION: z.string().default('v1'),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(16),
  JWT_EXPIRY: z.string().default('24h'),
  S3_ENDPOINT: z.string().url(),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string(),
  S3_SECRET_KEY: z.string(),
  S3_BUCKET: z.string(),
  S3_FORCE_PATH_STYLE: z.coerce.boolean().default(false),
  MEDIA_MAX_IMAGE: z.coerce.number().default(10485760),
  MEDIA_MAX_VIDEO: z.coerce.number().default(524288000),
  MEDIA_MAX_AUDIO: z.coerce.number().default(52428800),
  MEDIA_MAX_DOCUMENT: z.coerce.number().default(26214400),
  MEDIA_MAX_SCREENSHOT: z.coerce.number().default(10485760),
  DEFAULT_PAGE_LIMIT: z.coerce.number().default(20),
  MAX_PAGE_LIMIT: z.coerce.number().default(100),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Environment validation failed:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
