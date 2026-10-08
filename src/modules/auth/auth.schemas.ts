import { z } from 'zod';

export const CreateTokenSchema = z.object({
  purpose: z.enum(['trail_management']).default('trail_management'),
});

export const ReporterLoginSchema = z.object({
  reporterToken: z.string().min(1),
});

export type CreateTokenInput = z.infer<typeof CreateTokenSchema>;
export type ReporterLoginInput = z.infer<typeof ReporterLoginSchema>;
