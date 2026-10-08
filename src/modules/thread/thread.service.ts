import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { CreateThreadInput, ListThreadsQuery } from './thread.schemas';
import { decodeCursor, encodeCursor } from '../../utils/pagination';

export async function createThread(submissionId: string, userId: string, input: CreateThreadInput) {
  const submission = await prisma.submission.findUnique({ where: { id: submissionId } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', `Submission '${submissionId}' not found`);
  }

  return prisma.thread.create({
    data: {
      submissionId,
      content: input.content,
      locationText: input.locationText,
      userId,
    },
  });
}

export async function listThreads(submissionId: string, query: ListThreadsQuery) {
  const { cursor, limit = 20 } = query;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  const where: Record<string, unknown> = { submissionId };
  if (cursorId) where.id = { lt: cursorId };

  const threads = await prisma.thread.findMany({
    where,
    orderBy: { createdAt: 'asc' },
    take: limit + 1,
    include: {
      user: { select: { username: true } },
    },
  });

  const hasMore = threads.length > limit;
  const results = threads.slice(0, limit);
  const nextCursor = hasMore
    ? encodeCursor(results[results.length - 1].id)
    : undefined;

  return {
    data: results.map((t) => ({ ...t, author: t.user?.username || 'Anonymous' })),
    pagination: { nextCursor, hasMore },
  };
}
