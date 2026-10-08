import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { error as jsonError } from '../utils/response';

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof AppError) {
    return jsonError(res, err.statusCode, err.code, err.message, err.details);
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      return jsonError(res, 409, 'UNIQUE_VIOLATION', 'A resource with this identifier already exists');
    }
    if (err.code === 'P2025') {
      return jsonError(res, 404, 'NOT_FOUND', 'The requested resource was not found');
    }
    return jsonError(res, 500, 'DATABASE_ERROR', 'A database error occurred');
  }

  console.error('Unhandled error:', err);
  return jsonError(res, 500, 'INTERNAL_ERROR', 'An unexpected error occurred');
}
