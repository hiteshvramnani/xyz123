import jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';
import { env } from '../../config/env';
import { CreateTokenInput, ReporterLoginInput } from './auth.schemas';
import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';

export async function generateServiceToken(input: CreateTokenInput): Promise<{
  token: string;
  expiresIn: number;
  purpose: string;
}> {
  const sub = `service-${randomUUID()}`;
  const expiresIn = env.JWT_EXPIRY;

  const token = jwt.sign(
    { sub, purpose: input.purpose },
    env.JWT_SECRET,
    { expiresIn }
  );

  // Calculate numeric expiry for response
  const expirySeconds = typeof expiresIn === 'number'
    ? expiresIn
    : parseExpiryToSeconds(expiresIn);

  return { token, expiresIn: expirySeconds, purpose: input.purpose };
}

export async function loginReporter(input: ReporterLoginInput): Promise<{
  submissionIds: string[];
  submissionCount: number;
}> {
  const submissions = await prisma.submission.findMany({
    where: { reporterToken: input.reporterToken },
    select: { id: true },
    orderBy: { createdAt: 'desc' },
  });

  if (submissions.length === 0) {
    throw new AppError(401, 'INVALID_REPORTER_TOKEN', 'No submissions found for this reporter token');
  }

  return {
    submissionIds: submissions.map((s) => s.id),
    submissionCount: submissions.length,
  };
}

function parseExpiryToSeconds(expiry: string): number {
  const match = expiry.match(/^(\d+)(s|m|h|d)$/);
  if (!match) return 86400; // default 24h

  const value = parseInt(match[1], 10);
  const unit = match[2];

  switch (unit) {
    case 's': return value;
    case 'm': return value * 60;
    case 'h': return value * 3600;
    case 'd': return value * 86400;
    default: return 86400;
  }
}
