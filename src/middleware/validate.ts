import { Request, Response, NextFunction } from 'express';
import { ZodSchema } from 'zod';
import { AppError } from './error-handler';

export function validate(schema: ZodSchema, location: 'body' | 'query' | 'params') {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req[location]);
    if (!result.success) {
      throw new AppError(400, 'VALIDATION_ERROR', `Invalid ${location} data`, {
        errors: result.error.flatten().fieldErrors,
      });
    }
    req[location] = result.data;
    next();
  };
}
