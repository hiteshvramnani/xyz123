import { randomBytes } from 'crypto';
import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { CreateSubmissionInput, UpdateSubmissionInput, ListSubmissionsQuery } from './submission.schemas';
import { decodeCursor, encodeCursor } from '../../utils/pagination';

export async function createSubmission(trailSlug: string, input: CreateSubmissionInput, userId?: string) {
  const trail = await prisma.trail.findUnique({ where: { slug: trailSlug } });
  if (!trail) {
    throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail with slug '${trailSlug}' not found`);
  }

  const whenField = new Date(input.when);
  const timeWindowStart = input.timeWindowStart ? new Date(input.timeWindowStart) : undefined;
  const timeWindowEnd = input.timeWindowEnd ? new Date(input.timeWindowEnd) : undefined;

  const submission = await prisma.submission.create({
    data: {
      trailId: trail.id,
      what: input.what,
      whereField: input.where,
      whenField,
      timeWindowStart,
      timeWindowEnd,
      sourceChain: input.sourceChain,
      timeLag: input.timeLag,
      locationContext: input.locationContext,
      userId,
      metadata: input.metadata as any,
    },
  });

  return submission;
}

export async function getSubmission(id: string) {
  const submission = await prisma.submission.findUnique({
    where: { id },
    include: {
      trail: { select: { slug: true, name: true } },
      user: { select: { id: true, username: true, role: true } },
      media: { orderBy: { uploadedAt: 'asc' } },
      threads: { orderBy: { createdAt: 'asc' } },
    },
  });

  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', `Submission '${id}' not found`);
  }

  return {
    ...submission,
    trailSlug: submission.trail.slug,
    trailName: submission.trail.name,
    submittedBy: submission.user?.username || null,
    threadCount: submission.threads.length,
    mediaCount: submission.media.length,
  };
}

export async function updateSubmission(
  id: string,
  input: UpdateSubmissionInput
) {
  const submission = await prisma.submission.findUnique({ where: { id } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', `Submission '${id}' not found`);
  }

  const updateData: Record<string, unknown> = {};

  if (input.what !== undefined) updateData.what = input.what;
  if (input.where !== undefined) updateData.whereField = input.where;
  if (input.when !== undefined) updateData.whenField = new Date(input.when);
  if (input.timeWindowStart !== undefined) updateData.timeWindowStart = input.timeWindowStart ? new Date(input.timeWindowStart) : null;
  if (input.timeWindowEnd !== undefined) updateData.timeWindowEnd = input.timeWindowEnd ? new Date(input.timeWindowEnd) : null;
  if (input.sourceChain !== undefined) updateData.sourceChain = input.sourceChain;
  if (input.timeLag !== undefined) updateData.timeLag = input.timeLag;
  if (input.locationContext !== undefined) updateData.locationContext = input.locationContext;
  if (input.metadata !== undefined) updateData.metadata = input.metadata as any;

  return prisma.submission.update({
    where: { id },
    data: updateData,
  });
}

export async function listSubmissions(trailSlug: string, query: ListSubmissionsQuery) {
  const trail = await prisma.trail.findUnique({ where: { slug: trailSlug } });
  if (!trail) {
    throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail with slug '${trailSlug}' not found`);
  }

  const { cursor, limit = 20, dateFrom, dateTo } = query;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  const where: Record<string, unknown> = { trailId: trail.id };

  if (dateFrom) where.whenField = { gte: new Date(dateFrom) };
  if (dateTo) where.whenField = { lte: new Date(dateTo) };
  if (cursorId) where.id = { lt: cursorId };

  const submissions = await prisma.submission.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    select: {
      id: true,
      what: true,
      whereField: true,
      whenField: true,
      createdAt: true,
      updatedAt: true,
      user: { select: { username: true } },
      _count: {
        select: { media: true, threads: true },
      },
    },
  });

  const hasMore = submissions.length > limit;
  const results = submissions.slice(0, limit);
  const nextCursor = hasMore
    ? encodeCursor(results[results.length - 1].id)
    : undefined;

  return {
    data: results.map((s) => ({
      ...s,
      submittedBy: s.user?.username || null,
      mediaCount: s._count.media,
      threadCount: s._count.threads,
    })),
    pagination: { nextCursor, hasMore },
  };
}

export async function listMySubmissions(userId: string, query: ListSubmissionsQuery) {
  const { cursor, limit = 20, dateFrom, dateTo } = query;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  const where: Record<string, unknown> = { userId };

  if (dateFrom) where.whenField = { gte: new Date(dateFrom) };
  if (dateTo) where.whenField = { lte: new Date(dateTo) };
  if (cursorId) where.id = { lt: cursorId };

  const submissions = await prisma.submission.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    select: {
      id: true,
      what: true,
      whereField: true,
      whenField: true,
      createdAt: true,
      updatedAt: true,
      trail: { select: { slug: true, name: true } },
      _count: {
        select: { media: true, threads: true },
      },
    },
  });

  const hasMore = submissions.length > limit;
  const results = submissions.slice(0, limit);
  const nextCursor = hasMore
    ? encodeCursor(results[results.length - 1].id)
    : undefined;

  return {
    data: results.map((s) => ({
      ...s,
      trailSlug: s.trail.slug,
      trailName: s.trail.name,
      mediaCount: s._count.media,
      threadCount: s._count.threads,
    })),
    pagination: { nextCursor, hasMore },
  };
}
