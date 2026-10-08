import { z } from 'zod';

const GeoJSONPolygon = z.object({
  type: z.literal('Polygon'),
  coordinates: z.array(z.array(z.tuple([z.number(), z.number()]))),
});

export const CreateTrailSchema = z.object({
  name: z.string().min(1).max(255),
  description: z.string().max(5000).optional(),
  tags: z.array(z.string().max(50)).default([]),
  boundingBox: GeoJSONPolygon.optional(),
});

export const UpdateTrailSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  description: z.string().max(5000).nullable().optional(),
  tags: z.array(z.string().max(50)).optional(),
  boundingBox: GeoJSONPolygon.nullable().optional(),
});

export const ListTrailsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  tag: z.string().optional(),
  search: z.string().optional(),
});

export type CreateTrailInput = z.infer<typeof CreateTrailSchema>;
export type UpdateTrailInput = z.infer<typeof UpdateTrailSchema>;
export type ListTrailsQuery = z.infer<typeof ListTrailsQuerySchema>;
