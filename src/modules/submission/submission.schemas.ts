import { z } from 'zod';

// Accepts ISO datetime with or without timezone (e.g. "2026-09-23T12:00" from <input type="datetime-local">)
const LocalDatetime = z.string().refine(
  (v) => !isNaN(new Date(v).getTime()),
  { message: 'Invalid datetime' }
);

const GeoJSONPoint = z.object({
  type: z.literal('Point'),
  coordinates: z.tuple([z.number(), z.number()]),
});

export const CreateSubmissionSchema = z.object({
  what: z.string().min(1).max(50000),
  where: z.string().min(1).max(5000),
  when: LocalDatetime,
  timeWindowStart: LocalDatetime.optional(),
  timeWindowEnd: LocalDatetime.optional(),
  coordinates: GeoJSONPoint.optional(),
  sourceChain: z.string().max(5000).optional(),
  timeLag: z.number().int().min(0).optional(),
  locationContext: z.string().max(5000).optional(),
  metadata: z.record(z.unknown()).optional(),
});

export const UpdateSubmissionSchema = z.object({
  what: z.string().min(1).max(50000).optional(),
  where: z.string().min(1).max(5000).optional(),
  when: LocalDatetime.optional(),
  timeWindowStart: LocalDatetime.nullable().optional(),
  timeWindowEnd: LocalDatetime.nullable().optional(),
  coordinates: GeoJSONPoint.nullable().optional(),
  sourceChain: z.string().max(5000).nullable().optional(),
  timeLag: z.number().int().min(0).nullable().optional(),
  locationContext: z.string().max(5000).nullable().optional(),
  metadata: z.record(z.unknown()).nullable().optional(),
});

export const ListSubmissionsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
  nearLat: z.coerce.number().optional(),
  nearLng: z.coerce.number().optional(),
  radiusKm: z.coerce.number().optional(),
});

export type CreateSubmissionInput = z.infer<typeof CreateSubmissionSchema>;
export type UpdateSubmissionInput = z.infer<typeof UpdateSubmissionSchema>;
export type ListSubmissionsQuery = z.infer<typeof ListSubmissionsQuerySchema>;
