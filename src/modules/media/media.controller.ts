import { Request, Response } from 'express';
import http from 'http';
import https from 'https';
import path from 'path';
import { success } from '../../utils/response';
import { AppError } from '../../middleware/error-handler';
import { asyncHandler } from '../../utils/async-handler';
import { s3Service } from '../../services/s3.service';
import {
  getUploadUrl,
  finalizeMedia,
  getDownloadUrl,
  deleteMedia,
  getMediaRecord,
} from './media.service';
import { GetUploadUrlInput, FinalizeMediaInput } from './media.schemas';

const uploadDir = path.join(__dirname, '../../../uploads');

export const handleGetUploadUrl = asyncHandler(async (req: Request, res: Response) => {
  const reporterToken = req.header('x-reporter-token') as string;
  if (!reporterToken) {
    throw new AppError(401, 'UNAUTHORIZED', 'X-Reporter-Token header required');
  }
  const input = req.body as GetUploadUrlInput;
  const result = await getUploadUrl(req.params.id, reporterToken, input);
  return success(res, result);
});

export const handleFinalizeMedia = asyncHandler(async (req: Request, res: Response) => {
  const reporterToken = req.header('x-reporter-token') as string;
  if (!reporterToken) {
    throw new AppError(401, 'UNAUTHORIZED', 'X-Reporter-Token header required');
  }
  const input = req.body as FinalizeMediaInput;
  const media = await finalizeMedia(req.params.id, reporterToken, input);
  return success(res, media);
});

export const handleGetDownloadUrl = asyncHandler(async (req: Request, res: Response) => {
  const result = await getDownloadUrl(req.params.id);
  return success(res, result);
});

export const handleDeleteMedia = asyncHandler(async (req: Request, res: Response) => {
  const reporterToken = req.header('x-reporter-token') as string;
  if (!reporterToken) {
    throw new AppError(401, 'UNAUTHORIZED', 'X-Reporter-Token header required');
  }
  const result = await deleteMedia(req.params.id, reporterToken);
  return success(res, result);
});

export const handleStreamMedia = asyncHandler(async (req: Request, res: Response) => {
  const media = await getMediaRecord(req.params.id);

  // Local storage: read directly from disk
  if (process.env.FILE_STORAGE === 'local') {
    const filePath = path.join(uploadDir, media.s3Key);

    // Security: prevent path traversal
    if (!path.resolve(filePath).startsWith(path.resolve(uploadDir))) {
      throw new AppError(403, 'FORBIDDEN', 'Invalid file path');
    }

    res.setHeader('Cache-Control', 'public, max-age=3600');
    if (media.mimeType) res.setHeader('Content-Type', media.mimeType);
    res.sendFile(media.s3Key, { root: uploadDir }, (err) => {
      if (err && !res.headersSent) {
        throw new AppError(404, 'MEDIA_NOT_FOUND', 'File not found on disk');
      }
    });
    return;
  }

  // S3: proxy through signed URL
  const downloadUrl = await s3Service.getDownloadUrl(media.s3Key);
  const isHttps = downloadUrl.startsWith('https');
  const fetcher = isHttps ? https : http;

  const response: http.IncomingMessage = await new Promise((resolve, reject) => {
    const streamReq = fetcher.get(downloadUrl, resolve).on('error', reject);
    streamReq.setTimeout(10000, () => {
      streamReq.destroy();
      reject(new AppError(504, 'GATEWAY_TIMEOUT', 'Upstream storage timed out'));
    });
  });

  if (response.statusCode !== 200) {
    // Consume the response body to free up socket
    response.resume();
    throw new AppError(response.statusCode ?? 502, 'UPSTREAM_ERROR', 'Failed to fetch media from storage');
  }

  const contentType = response.headers['content-type'];
  const contentLength = response.headers['content-length'];

  res.setHeader('Cache-Control', 'public, max-age=3600');
  if (contentType) res.setHeader('Content-Type', contentType);
  if (contentLength) res.setHeader('Content-Length', contentLength);

  response.pipe(res);
});
