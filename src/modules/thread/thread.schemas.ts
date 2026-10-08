import { z } from 'zod';

const GeoJSONPoint = z.object({
  type: z.literal('Point'),
  coordinates: z.tuple([z.number(), z.number()]),
});

export const CreateThreadSchema = z.object({
  content: z.string().min(1).max(50000),
  locationText: z.string().max(5000).optional(),
  coordinates: GeoJSONPoint.optional(),
  metadata: z.record(z.unknown()).optional(),
});

export const ListThreadsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

export type CreateThreadInput = z.infer<typeof CreateThreadSchema>;
export type ListThreadsQuery = z.infer<typeof ListThreadsQuerySchema>;
