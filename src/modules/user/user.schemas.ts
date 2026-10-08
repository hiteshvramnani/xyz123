import { z } from 'zod';

export const LoginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export const CreateUserSchema = z.object({
  username: z.string().min(1).max(50),
  password: z.string().min(4),
  role: z.enum(['ADMIN', 'USER']).default('USER'),
});

export const UpdateUserStatusSchema = z.object({
  active: z.boolean(),
});

export type LoginInput = z.infer<typeof LoginSchema>;
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
