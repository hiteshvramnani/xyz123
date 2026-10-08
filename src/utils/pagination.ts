import { Request } from 'express';
import { env } from '../config/env';

export interface PaginationQuery {
  cursor?: string;
  limit: number;
}

export function parsePaginationQuery(req: Request): PaginationQuery {
  const cursor = req.query.cursor as string | undefined;
  const limitRaw = req.query.limit as string | undefined;
  const limit = limitRaw ? Math.min(Math.max(parseInt(limitRaw, 10), 1), env.MAX_PAGE_LIMIT) : env.DEFAULT_PAGE_LIMIT;
  return { cursor, limit };
}

export function encodeCursor(id: string): string {
  return Buffer.from(id).toString('base64url');
}

export function decodeCursor(cursor: string): string {
  return Buffer.from(cursor, 'base64url').toString('utf-8');
}
