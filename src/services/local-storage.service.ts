import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

const uploadDir = path.join(__dirname, '../../uploads');
const publicUrl = process.env.PUBLIC_URL || `http://localhost:${process.env.PORT || 3000}`;

const fileExtensionMap: Record<string, string> = {
  'image/jpeg': 'jpeg', 'image/jpg': 'jpg', 'image/png': 'png',
  'image/gif': 'gif', 'image/webp': 'webp', 'image/tiff': 'tiff',
  'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm',
  'audio/mpeg': 'mp3', 'audio/wav': 'wav', 'audio/ogg': 'ogg',
  'audio/webm': 'webm', 'audio/mp4': 'm4a',
  'application/pdf': 'pdf', 'text/plain': 'txt', 'text/csv': 'csv',
};

if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

export class LocalStorageService {
  private getExtension(mimeType: string): string {
    return fileExtensionMap[mimeType] || 'bin';
  }

  async getUploadUrl(
    submissionId: string,
    mimeType: string,
    _fileSizeBytes: number
  ): Promise<{ uploadUrl: string; s3Key: string; expiresIn: number }> {
    const ext = this.getExtension(mimeType);
    const key = `media/${submissionId}/${randomUUID()}.${ext}`;
    const uploadPath = path.join(uploadDir, key);
    fs.mkdirSync(path.dirname(uploadPath), { recursive: true });

    return {
      uploadUrl: `${publicUrl}/uploads/${key}`,
      s3Key: key,
      expiresIn: 900,
    };
  }

  async getDownloadUrl(s3Key: string, _expiresIn = 3600): Promise<string> {
    return `${publicUrl}/uploads/${s3Key}`;
  }

  async getThumbnailUrl(thumbnailS3Key: string, _expiresIn = 3600): Promise<string | null> {
    if (!thumbnailS3Key) return null;
    return this.getDownloadUrl(thumbnailS3Key);
  }
}

export const localStorageService = new LocalStorageService();
