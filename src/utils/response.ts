import { Response } from 'express';

export interface PaginationMeta {
  nextCursor?: string;
  hasMore: boolean;
  total?: number;
}

// JSON.stringify replacer that converts BigInt values to strings so Express doesn't crash
const bigIntReplacer = (_: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

export function success<T>(
  res: Response,
  data: T,
  pagination?: PaginationMeta
) {
  const body: Record<string, unknown> = { success: true, data };
  if (pagination) body.pagination = pagination;
  res.set('Content-Type', 'application/json');
  return res.send(JSON.stringify(body, bigIntReplacer));
}

export function error(res: Response, statusCode: number, code: string, message: string, details?: Record<string, unknown>) {
  const body: Record<string, unknown> = { success: false, error: { code, message } };
  if (details) body.error.details = details;
  res.set('Content-Type', 'application/json');
  return res.status(statusCode).send(JSON.stringify(body, bigIntReplacer));
}
