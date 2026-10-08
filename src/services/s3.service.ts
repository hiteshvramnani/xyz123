import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import { env } from '../config/env';
import { localStorageService } from './local-storage.service';

// Use local file storage when FILE_STORAGE=local, otherwise S3
const useLocal = process.env.FILE_STORAGE === 'local';

const fileExtensionMap: Record<string, string> = {
  'image/jpeg': 'jpeg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'image/tiff': 'tiff',
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/ogg': 'ogg',
  'audio/webm': 'webm',
  'audio/mp4': 'm4a',
  'application/pdf': 'pdf',
  'application/csv': 'csv',
  'application/vnd.ms-excel': 'xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'application/msword': 'doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'text/plain': 'txt',
  'text/csv': 'csv',
};

export class S3Service {
  private client: S3Client | null = null;
  private bucket: string | null = null;

  constructor() {
    if (!useLocal) {
      this.client = new S3Client({
        endpoint: env.S3_ENDPOINT,
        region: env.S3_REGION,
        credentials: {
          accessKeyId: env.S3_ACCESS_KEY,
          secretAccessKey: env.S3_SECRET_KEY,
        },
        forcePathStyle: env.S3_FORCE_PATH_STYLE,
      });
      this.bucket = env.S3_BUCKET;
    }
  }

  private getExtension(mimeType: string): string {
    return fileExtensionMap[mimeType] || 'bin';
  }

  async getUploadUrl(
    submissionId: string,
    mimeType: string,
    fileSizeBytes: number
  ): Promise<{ uploadUrl: string; s3Key: string; expiresIn: number }> {
    if (useLocal) {
      return localStorageService.getUploadUrl(submissionId, mimeType, fileSizeBytes);
    }

    const extension = this.getExtension(mimeType);
    const key = `media/${submissionId}/${randomUUID()}.${extension}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket!,
      Key: key,
      ContentType: mimeType,
      ContentLength: fileSizeBytes,
    });

    const expiresIn = 900;
    const url = await getSignedUrl(this.client!, command, { expiresIn });
    return { uploadUrl: url, s3Key: key, expiresIn };
  }

  async getDownloadUrl(
    s3Key: string,
    expiresIn = 3600
  ): Promise<string> {
    if (useLocal) {
      return localStorageService.getDownloadUrl(s3Key, expiresIn);
    }

    const command = new GetObjectCommand({
      Bucket: this.bucket!,
      Key: s3Key,
    });
    return await getSignedUrl(this.client!, command, { expiresIn });
  }

  async getThumbnailUrl(
    thumbnailS3Key: string,
    expiresIn = 3600
  ): Promise<string | null> {
    if (useLocal) {
      return localStorageService.getThumbnailUrl(thumbnailS3Key, expiresIn);
    }

    if (!thumbnailS3Key) return null;
    return this.getDownloadUrl(thumbnailS3Key, expiresIn);
  }
}

export const s3Service = new S3Service();
