import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { SearchQuery, GeoSearchQuery } from './search.schemas';
import { decodeCursor, encodeCursor } from '../../utils/pagination';

export async function searchSubmissions(query: SearchQuery) {
  const { q, trailSlug, dateFrom, dateTo, cursor, limit = 20 } = query;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  let trailId: string | undefined;
  if (trailSlug) {
    const trail = await prisma.trail.findUnique({ where: { slug: trailSlug }, select: { id: true } });
    if (!trail) throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail '${trailSlug}' not found`);
    trailId = trail.id;
  }

  const params: (string | Date | number | string[] | null)[] = [];
  const paramParts: string[] = [];

  params.push(q);
  paramParts.push(`to_tsvector('english', COALESCE(s."what", '') || ' ' || COALESCE(s."where_field", '')) @@ plainto_tsquery('english', $${params.length})`);

  if (trailId) {
    params.push(trailId);
    paramParts.push(`s."trail_id" = $${params.length}`);
  }

  if (dateFrom) {
    params.push(new Date(dateFrom));
    paramParts.push(`s."when_field" >= $${params.length}`);
  }

  if (dateTo) {
    params.push(new Date(dateTo));
    paramParts.push(`s."when_field" <= $${params.length}`);
  }

  if (cursorId) {
    params.push(cursorId);
    paramParts.push(`s."id"::text < $${params.length}`);
  }

  params.push(limit + 1);

  const sql = `
    SELECT s.id, s."trail_id", s."what", s."where_field", s."when_field",
           s."createdAt",
           t."slug_text" as trail_slug, t."name" as trail_name,
           (SELECT COUNT(*) FROM "media" m WHERE m."submission_id" = s.id) as media_count,
           (SELECT COUNT(*) FROM "threads" th WHERE th."submission_id" = s.id) as thread_count,
           ts_rank(to_tsvector('english', COALESCE(s."what", '') || ' ' || COALESCE(s."where_field", '')),
                   plainto_tsquery('english', $1)) as rank
    FROM "submissions" s
    JOIN "trails" t ON t.id = s."trail_id"
    ${paramParts.length ? 'WHERE ' + paramParts.join(' AND ') : ''}
    ORDER BY rank DESC, s."createdAt" DESC
    LIMIT $${params.length}
  `;

  const results = await prisma.$queryRawUnsafe(sql, ...params);
  const hasMore = results.length > limit;
  const items = results.slice(0, limit);
  const nextCursor = hasMore && items.length
    ? encodeCursor(items[items.length - 1].id)
    : undefined;

  return {
    data: items.map((r: any) => ({
      type: 'submission',
      id: r.id,
      trailSlug: r.trail_slug,
      trailName: r.trail_name,
      what: r.what,
      where: r.where_field,
      when: r.when_field,
      mediaCount: Number(r.media_count),
      threadCount: Number(r.thread_count),
      createdAt: r.createdAt,
    })),
    pagination: { nextCursor, hasMore },
  };
}

export async function searchNear(query: GeoSearchQuery) {
  const { lat, lng, radiusKm, trailSlug, cursor, limit = 20 } = query;
  const cursorId = cursor ? decodeCursor(cursor) : undefined;

  let trailId: string | undefined;
  if (trailSlug) {
    const trail = await prisma.trail.findUnique({ where: { slug: trailSlug }, select: { id: true } });
    if (!trail) throw new AppError(404, 'TRAIL_NOT_FOUND', `Trail '${trailSlug}' not found`);
    trailId = trail.id;
  }

  const trailFilter = trailId ? `AND s."trail_id" = '${trailId}'` : '';
  const cursorFilter = cursorId ? `AND s."id"::text < '${cursorId}'` : '';
  const limitVal = limit + 1;

  const sql = `
    SELECT s.id, s."trail_id", s."what", s."where_field", s."when_field",
           s."createdAt",
           t."slug_text" as trail_slug, t."name" as trail_name,
           (SELECT COUNT(*) FROM "media" m WHERE m."submission_id" = s.id) as media_count,
           (SELECT COUNT(*) FROM "threads" th WHERE th."submission_id" = s.id) as thread_count
    FROM "submissions" s
    JOIN "trails" t ON t.id = s."trail_id"
    WHERE 1=1 ${trailFilter} ${cursorFilter}
    ORDER BY s."createdAt" DESC
    LIMIT ${limitVal}
  `;

  const results = await prisma.$queryRawUnsafe(sql);
  const hasMore = results.length > limit;
  const items = results.slice(0, limit);
  const nextCursor = hasMore && items.length
    ? encodeCursor(items[items.length - 1].id)
    : undefined;

  return {
    data: items.map((r: any) => ({
      type: 'submission',
      id: r.id,
      trailSlug: r.trail_slug,
      trailName: r.trail_name,
      what: r.what,
      where: r.where_field,
      when: r.when_field,
      mediaCount: Number(r.media_count),
      threadCount: Number(r.thread_count),
      createdAt: r.createdAt,
    })),
    pagination: { nextCursor, hasMore },
  };
}
