import prisma from '../../db/client';
import slugify from 'slugify';
import { AppError } from '../../middleware/error-handler';
import { CreateTrailInput, UpdateTrailInput, ListTrailsQuery } from './trail.schemas';
import { decodeCursor, encodeCursor } from '../../utils/pagination';

export async function createTrail(input: CreateTrailInput, createdBy: string) {
  let slug = slugify(input.name, { lower: true, strict: true });

  const existing = await prisma.trail.findUnique({ where: { slug } });
  if (existing) {
    const suffix = Math.random().toString(36).slice(2, 6);
    slug = `${slug}-${suffix}`;
  }

  return prisma.trail.create({
    data: {
      slug,
      name: input.name,
      description: input.description,
      tags: input.tags,
      createdBy,
    },
  });
}

export async function listTrails(query: ListTrailsQuery) {
  const { cursor, limit = 20, tag, search } = query;
  const skip = cursor ? 1 : 0;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  const where: Record<string, unknown> = {};

  if (tag) {
    where.tags = { has: tag };
  }

  if (search) {
    where.OR = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];
  }

  if (cursorId) {
    where.id = { lt: cursorId };
  }

  const trails = await prisma.trail.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    skip,
    select: {
      id: true,
      slug: true,
      name: true,
      description: true,
      tags: true,
      createdAt: true,
      updatedAt: true,
      _count: { select: { submissions: true } },
    },
  });

  const hasMore = trails.length > limit;
  const results = trails.slice(0, limit);

  const nextCursor = hasMore
    ? encodeCursor(results[results.length - 1].id)
    : undefined;

  return {
    data: results.map((t) => ({
      ...t,
      submissionCount: t._count.submissions,
    })),
    pagination: { nextCursor, hasMore },
  };
}

export async function getTrailBySlug(slug: string) {
  const trail = await prisma.trail.findUnique({
    where: { slug },
    select: {
      id: true,
      slug: true,
      name: true,
      description: true,
      tags: true,
      createdAt: true,
      updatedAt: true,
      _count: { select: { submissions: true } },
    },
  });

  if (!trail) {
    throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail with slug '${slug}' not found`);
  }

  return {
    ...trail,
    submissionCount: trail._count.submissions,
  };
}

export async function updateTrail(slug: string, input: UpdateTrailInput) {
  const trail = await prisma.trail.findUnique({ where: { slug } });
  if (!trail) {
    throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail with slug '${slug}' not found`);
  }

  const updateData: Record<string, unknown> = {};

  if (input.name !== undefined && input.name !== trail.name) {
    let newSlug = slugify(input.name, { lower: true, strict: true });
    const existing = await prisma.trail.findUnique({ where: { slug: newSlug } });
    if (existing && existing.id !== trail.id) {
      const suffix = Math.random().toString(36).slice(2, 6);
      newSlug = `${newSlug}-${suffix}`;
    }
    updateData.name = input.name;
    updateData.slug = newSlug;
  }

  if (input.description !== undefined) updateData.description = input.description;
  if (input.tags !== undefined) updateData.tags = input.tags;

  return prisma.trail.update({
    where: { slug },
    data: updateData,
  });
}

export async function deleteTrail(slug: string) {
  const trail = await prisma.trail.findUnique({ where: { slug } });
  if (!trail) {
    throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail with slug '${slug}' not found`);
  }

  await prisma.trail.delete({ where: { slug } });
  return { deleted: true };
}
