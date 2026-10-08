import { z } from 'zod';

export const SubmitEvidenceSchema = z.object({
  title: z.string().max(50000).optional(),
  location: z.string().max(5000).optional(),
  deviceInfo: z.string().max(5000).optional(),
  timezone: z.string().max(200).optional(),
  browserId: z.string().max(64).optional(),
  phoneNumber: z.string().max(30).optional(),
  manualLocation: z.string().max(5000).optional(),
  phoneNumbers: z.array(z.string().max(30)).optional(),
  locations: z.array(z.string().max(5000)).optional(),
});

export const EvidenceFileSchema = z.object({
  mimeType: z.string(),
  fileSizeBytes: z.number().int().min(0),
  fileName: z.string().min(1),
});

export type SubmitEvidenceInput = z.infer<typeof SubmitEvidenceSchema>;
export type EvidenceFileInput = z.infer<typeof EvidenceFileSchema>;
