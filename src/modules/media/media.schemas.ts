import { z } from 'zod';

export const MediaTypeEnum = z.enum(['IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT', 'SCREENSHOT']);

export const GetUploadUrlSchema = z.object({
  mediaType: MediaTypeEnum,
  mimeType: z.string(),
  fileSizeBytes: z.number().int().positive(),
});

export const FinalizeMediaSchema = z.object({
  s3Key: z.string(),
  mediaType: MediaTypeEnum,
  mimeType: z.string(),
  fileSizeBytes: z.number().int().positive(),
  caption: z.string().max(5000).optional(),
});

export type GetUploadUrlInput = z.infer<typeof GetUploadUrlSchema>;
export type FinalizeMediaInput = z.infer<typeof FinalizeMediaSchema>;
