import { z } from 'zod';

export const SearchQuerySchema = z.object({
  q: z.string().min(1),
  trailSlug: z.string().optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

export const GeoSearchQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radiusKm: z.coerce.number().positive().default(10),
  trailSlug: z.string().optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

export type SearchQuery = z.infer<typeof SearchQuerySchema>;
export type GeoSearchQuery = z.infer<typeof GeoSearchQuerySchema>;
