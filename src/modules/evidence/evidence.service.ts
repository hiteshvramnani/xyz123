import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { s3Service } from '../../services/s3.service';
import { SubmitEvidenceInput, EvidenceFileInput } from './evidence.schemas';

export async function submitEvidence(input: SubmitEvidenceInput & { phoneNumber?: string; manualLocation?: string; phoneNumbers?: string[]; locations?: string[] }, files: EvidenceFileInput[]) {
  // Use first trail or create a default "evidence" trail
  let trail = await prisma.trail.findFirst({ where: { slug: 'evidence' } });
  if (!trail) {
    trail = await prisma.trail.create({
      data: { slug: 'evidence', name: 'Evidence', tags: ['evidence'], createdBy: 'system' },
    });
  }

  const submission = await prisma.submission.create({
    data: {
      trailId: trail.id,
      what: input.title ?? '',
      whereField: input.location ?? '',
      whenField: new Date(),
      reporterToken: input.browserId,
      metadata: {
        deviceInfo: input.deviceInfo,
        timezone: input.timezone,
        parts: [{
          title: input.title?.trim(),
          createdAt: new Date().toISOString(),
          ...(input.phoneNumber?.trim() && { phoneNumber: input.phoneNumber.trim() }),
          ...(input.phoneNumbers && input.phoneNumbers.length > 0 && { phoneNumbers: input.phoneNumbers }),
          ...(input.manualLocation?.trim() && { manualLocation: input.manualLocation.trim() }),
          ...(input.locations && input.locations.length > 0 && { locations: input.locations }),
        }],
      },
    },
  });

  // Generate presigned upload URLs and create media records
  const uploadUrls = await Promise.all(files.map(async (f) => {
    const { uploadUrl, s3Key, expiresIn } = await s3Service.getUploadUrl(
      submission.id,
      f.mimeType,
      f.fileSizeBytes,
    );

    // Determine media type from MIME type
    let mediaType: 'IMAGE' | 'VIDEO' | 'AUDIO' | 'DOCUMENT' | 'SCREENSHOT' = 'DOCUMENT';
    if (f.mimeType.startsWith('image/')) mediaType = 'IMAGE';
    else if (f.mimeType.startsWith('video/')) mediaType = 'VIDEO';
    else if (f.mimeType.startsWith('audio/')) mediaType = 'AUDIO';

    // Create media record in DB now (file will be uploaded via presigned URL)
    await prisma.media.create({
      data: {
        submissionId: submission.id,
        mediaType,
        s3Key,
        mimeType: f.mimeType,
        fileSizeBytes: BigInt(f.fileSizeBytes),
        caption: f.fileName,
        partIndex: 0,
      },
    });

    return {
      fileName: f.fileName,
      mimeType: f.mimeType,
      fileSizeBytes: f.fileSizeBytes,
      uploadUrl,
      s3Key,
      expiresIn,
    };
  }));

  return {
    submissionId: submission.id,
    uploadUrls,
  };
}

export async function finalizeEvidence(submissionId: string, s3Keys: string[]) {
  const submission = await prisma.submission.findUnique({ where: { id: submissionId } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', 'Submission not found');
  }

  // Verify all media records exist (they were created on submit)
  const media = await prisma.media.findMany({
    where: { submissionId, s3Key: { in: s3Keys } },
  });

  const foundKeys = new Set(media.map((m) => m.s3Key));
  const missingKeys = s3Keys.filter((key) => !foundKeys.has(key));

  if (missingKeys.length > 0) {
    console.error(
      `[finalizeEvidence] Missing media records for submission ${submissionId}:`,
      missingKeys,
      `Found keys: ${JSON.stringify(Array.from(foundKeys))}`
    );
    throw new AppError(400, 'INVALID_MEDIA', 'Some files were not found. Upload them first.');
  }

  return { submissionId, mediaCount: s3Keys.length };
}

export async function updateSubmissionTitle(submissionId: string, title: string) {
  const submission = await prisma.submission.findUnique({ where: { id: submissionId } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', 'Submission not found');
  }

  const trimmedTitle = title.trim();

  const metadata = (submission.metadata as Record<string, unknown> | null) || {};
  const parts = ((metadata.parts as Array<{ title?: string; createdAt: string }>) || []) as Array<{ title?: string; createdAt: string }>;

  // Update the title in the first part entry
  if (parts.length > 0) {
    parts[0].title = trimmedTitle;
  }

  await prisma.submission.update({
    where: { id: submissionId },
    data: {
      what: trimmedTitle,
      metadata: { ...metadata, parts },
    },
  });
}

export async function listMySubmissions(browserId: string, query?: { q?: string; hasImage?: boolean; hasVideo?: boolean; hasPhoneNumber?: boolean; hasLocation?: boolean; hasTitle?: boolean; page?: number; limit?: number }) {
  const trail = await prisma.trail.findFirst({ where: { slug: 'evidence' } });
  if (!trail) {
    return { data: [], pagination: { page: 1, totalPages: 0, total: 0, hasMore: false } };
  }

  const { q, hasImage, hasVideo, hasPhoneNumber, hasLocation, hasTitle, page = 1, limit = 20 } = query || {};

  const binds: (string | Date | number)[] = [];
  const wheres: string[] = [];
  let idx = 1;
  const bind = (v: string | Date | number) => {
    binds.push(v);
    const i = idx++;
    return `$${i}`;
  };

  wheres.push(`s."trail_id" = ${bind(trail.id)}`);
  wheres.push(`s."reporter_token" = ${bind(browserId)}`);

  if (q?.trim()) {
    const sv = `%${q.trim()}%`;
    wheres.push(`(LOWER(s."what") LIKE ${bind(sv.toLowerCase())})`);
  }

  if (hasImage) {
    wheres.push(`EXISTS (SELECT 1 FROM "media" m WHERE m."submission_id" = s.id AND CAST(m."mediaType" AS TEXT) = 'IMAGE')`);
  }
  if (hasVideo) {
    wheres.push(`EXISTS (SELECT 1 FROM "media" m WHERE m."submission_id" = s.id AND CAST(m."mediaType" AS TEXT) = 'VIDEO')`);
  }
  if (hasPhoneNumber) {
    wheres.push(`(s."metadata"->'parts'->0 IS NOT NULL AND (s."metadata"->'parts'->0->>'phoneNumber' IS NOT NULL OR s."metadata"->'parts'->0->>'phoneNumbers' IS NOT NULL))`);
  }
  if (hasLocation) {
    wheres.push(`(s."metadata"->'parts'->0 IS NOT NULL AND (s."metadata"->'parts'->0->>'manualLocation' IS NOT NULL OR s."metadata"->'parts'->0->>'locations' IS NOT NULL))`);
  }
  if (hasTitle) {
    wheres.push(`(s."what" IS NOT NULL AND s."what" != '')`);
  }

    // 1. Get the total matching count for pagination boundaries
  const countSql = `
    SELECT COUNT(*)::int as total FROM "submissions" s
    WHERE ${wheres.join(' AND ')}
  `;
  const countResults = await prisma.$queryRawUnsafe<{ total: number }[]>(countSql, ...binds);
  const total = Number(countResults?.[0]?.total ?? 0);

  // 2. Clone the binds array to dynamically separate list tokens from count tokens
  const queryBinds = [...binds];

  // 3. Increment parameter tokens based on the current idx track location
  const limitIdx = idx;
  const offsetIdx = idx + 1;
  queryBinds.push(limit, (page - 1) * limit);

  const sql = `
    SELECT s.id, s."what", s."where_field" as "whereField", s."when_field" as "whenField",
           s."createdAt", s."updatedAt", s."metadata",
           (SELECT COUNT(*) FROM "media" m WHERE m."submission_id" = s.id)::int as "mediaCount",
           (SELECT COUNT(*) FROM "threads" th WHERE th."submission_id" = s.id)::int as "threadCount"
    FROM "submissions" s
    WHERE ${wheres.join(' AND ')}
    ORDER BY s."createdAt" DESC
    LIMIT $${limitIdx} OFFSET $${offsetIdx}
  `;

  // 4. Execute the targeted selection using the custom boundary parameter block
  const results = await prisma.$queryRawUnsafe<any[]>(sql, ...queryBinds);



  console.log('[listMySubmissions] found', results.length, 'of', total, 'submissions (page', page, ')');

  const totalPages = Math.ceil(total / limit);

  return {
    data: results.map((r) => ({
      ...r,
      metadata: r.metadata ?? {},
    })),
    pagination: { page, totalPages, total, hasMore: page < totalPages },
  };
}

export async function addToSubmission(submissionId: string, title: string | undefined, files: EvidenceFileInput[], phoneNumber?: string, manualLocation?: string, phoneNumbers?: string[], locations?: string[]) {
  const submission = await prisma.submission.findUnique({ where: { id: submissionId } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', 'Submission not found');
  }

  const metadata = (submission.metadata as Record<string, unknown> | null) || {};
  const parts = (metadata.parts as Array<{ title?: string; createdAt: string }> | undefined) || [];

  // If no parts array exists yet, seed it from the original submission
  if (parts.length === 0 && submission.what?.trim()) {
    parts.push({ title: submission.what.trim(), createdAt: submission.createdAt.toISOString() });
  }

  // New part index is the current parts count
  const newPartIndex = parts.length;

  // Build the part data object
  const partData: Record<string, unknown> = { createdAt: new Date().toISOString() };
  if (title?.trim()) partData.title = title.trim();
  if (phoneNumber?.trim()) partData.phoneNumber = phoneNumber.trim();
  if (phoneNumbers && phoneNumbers.length > 0) partData.phoneNumbers = phoneNumbers;
  if (manualLocation?.trim()) partData.manualLocation = manualLocation.trim();
  if (locations && locations.length > 0) partData.locations = locations;

  // Add new part entry
  if (title?.trim()) {
    if (!submission.what?.trim()) {
      // First title ever set
      await prisma.submission.update({
        where: { id: submissionId },
        data: { what: title.trim() },
      });
    }
    parts.push(partData);
  } else if (parts.length === 0) {
    // No title and no previous parts — still track the addition
    if (!partData.title) partData.title = files[0]?.fileName || '';
    parts.push(partData);
  } else {
    parts.push(partData);
  }

  await prisma.submission.update({
    where: { id: submissionId },
    data: {
      metadata: { ...metadata, parts },
    },
  });

  const uploadUrls = await Promise.all(files.map(async (f) => {
    const { uploadUrl, s3Key, expiresIn } = await s3Service.getUploadUrl(
      submissionId,
      f.mimeType,
      f.fileSizeBytes,
    );

    let mediaType: 'IMAGE' | 'VIDEO' | 'AUDIO' | 'DOCUMENT' | 'SCREENSHOT' = 'DOCUMENT';
    if (f.mimeType.startsWith('image/')) mediaType = 'IMAGE';
    else if (f.mimeType.startsWith('video/')) mediaType = 'VIDEO';
    else if (f.mimeType.startsWith('audio/')) mediaType = 'AUDIO';

    await prisma.media.create({
      data: {
        submissionId,
        mediaType,
        s3Key,
        mimeType: f.mimeType,
        fileSizeBytes: BigInt(f.fileSizeBytes),
        caption: title?.trim() || f.fileName,
        partIndex: newPartIndex,
      },
    });

    return {
      fileName: f.fileName,
      mimeType: f.mimeType,
      fileSizeBytes: f.fileSizeBytes,
      uploadUrl,
      s3Key,
      expiresIn,
    };
  }));

  return { submissionId, uploadUrls };
}