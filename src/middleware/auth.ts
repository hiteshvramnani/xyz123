import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { AppError } from './error-handler';
import prisma from '../db/client';

export interface AuthRequest extends Request {
  serviceToken?: {
    sub: string;
    purpose: string;
  };
  reporterToken?: string;
  user?: {
    userId: string;
    username: string;
    role: string;
  };
}

export function requireServiceToken(req: AuthRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new AppError(401, 'UNAUTHORIZED', 'Bearer token required');
  }

  const token = header.split(' ')[1];
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as { sub: string; purpose: string };
    req.serviceToken = payload;
    next();
  } catch {
    throw new AppError(401, 'INVALID_TOKEN', 'Invalid or expired token');
  }
}

export async function requireReporterToken(req: AuthRequest, _res: Response, next: NextFunction) {
  const token = req.header('X-Reporter-Token');
  if (!token) {
    throw new AppError(401, 'UNAUTHORIZED', 'X-Reporter-Token header required');
  }

  const count = await prisma.submission.count({ where: { reporterToken: token } });
  if (count === 0) {
    throw new AppError(401, 'INVALID_REPORTER_TOKEN', 'Unknown reporter token');
  }

  req.reporterToken = token;
  next();
}

export function requireAuth(req: AuthRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new AppError(401, 'UNAUTHORIZED', 'Bearer token required');
  }

  const token = header.split(' ')[1];
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as { userId: string; username: string; role: string };
    req.user = payload;
    next();
  } catch {
    throw new AppError(401, 'INVALID_TOKEN', 'Invalid or expired token');
  }
}

export function requireAdmin(req: AuthRequest, _res: Response, next: NextFunction) {
  if (!req.user) {
    throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  }
  if (req.user.role !== 'ADMIN') {
    throw new AppError(403, 'FORBIDDEN', 'Admin access required');
  }
  next();
}
