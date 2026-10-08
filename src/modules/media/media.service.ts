import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { s3Service } from '../../services/s3.service';
import { env } from '../../config/env';
import { GetUploadUrlInput, FinalizeMediaInput } from './media.schemas';

const fileSizeLimits: Record<string, number> = {
  IMAGE: env.MEDIA_MAX_IMAGE,
  VIDEO: env.MEDIA_MAX_VIDEO,
  AUDIO: env.MEDIA_MAX_AUDIO,
  DOCUMENT: env.MEDIA_MAX_DOCUMENT,
  SCREENSHOT: env.MEDIA_MAX_SCREENSHOT,
};

export async function validateReporterOwnership(submissionId: string, reporterToken: string) {
  const submission = await prisma.submission.findUnique({ where: { id: submissionId } });
  if (!submission) {
    throw new AppError(404, 'SUBMISSION_NOT_FOUND', `Submission '${submissionId}' not found`);
  }
  if (submission.reporterToken !== reporterToken) {
    throw new AppError(403, 'FORBIDDEN', 'Reporter token does not match this submission');
  }
  return submission;
}

export async function getUploadUrl(submissionId: string, reporterToken: string, input: GetUploadUrlInput) {
  await validateReporterOwnership(submissionId, reporterToken);

  const maxBytes = fileSizeLimits[input.mediaType];
  if (input.fileSizeBytes > maxBytes) {
    throw new AppError(
      400,
      'FILE_TOO_LARGE',
      `File size exceeds maximum allowed size of ${maxBytes} bytes for ${input.mediaType}`,
    );
  }

  const { uploadUrl, s3Key, expiresIn } = await s3Service.getUploadUrl(
    submissionId,
    input.mimeType,
    input.fileSizeBytes,
  );

  return { uploadUrl, s3Key, expiresIn };
}

export async function finalizeMedia(submissionId: string, reporterToken: string, input: FinalizeMediaInput) {
  await validateReporterOwnership(submissionId, reporterToken);

  return prisma.media.create({
    data: {
      submissionId,
      mediaType: input.mediaType,
      s3Key: input.s3Key,
      mimeType: input.mimeType,
      fileSizeBytes: BigInt(input.fileSizeBytes),
      caption: input.caption,
    },
  });
}

export async function getDownloadUrl(mediaId: string) {
  const media = await prisma.media.findUnique({ where: { id: mediaId } });
  if (!media) {
    throw new AppError(404, 'MEDIA_NOT_FOUND', `Media '${mediaId}' not found`);
  }

  const downloadUrl = await s3Service.getDownloadUrl(media.s3Key);
  const thumbnailUrl = await s3Service.getThumbnailUrl(media.thumbnailS3Key);

  return {
    id: media.id,
    mediaType: media.mediaType,
    mimeType: media.mimeType,
    downloadUrl,
    thumbnailUrl,
    expiresIn: 3600,
  };
}

export async function deleteMedia(mediaId: string, reporterToken: string) {
  const media = await prisma.media.findUnique({ where: { id: mediaId } });
  if (!media) {
    throw new AppError(404, 'MEDIA_NOT_FOUND', `Media '${mediaId}' not found`);
  }

  await validateReporterOwnership(media.submissionId, reporterToken);
  await prisma.media.delete({ where: { id: mediaId } });

  return { deleted: true };
}

export async function getMediaRecord(mediaId: string) {
  const media = await prisma.media.findUnique({ where: { id: mediaId } });
  if (!media) {
    throw new AppError(404, 'MEDIA_NOT_FOUND', `Media '${mediaId}' not found`);
  }
  return media;
}
