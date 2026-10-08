import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { AppError } from '../../middleware/error-handler';
import { asyncHandler } from '../../utils/async-handler';
import { submitEvidence, finalizeEvidence, listMySubmissions, addToSubmission, updateSubmissionTitle } from './evidence.service';
import { SubmitEvidenceInput, EvidenceFileInput } from './evidence.schemas';

export const handleSubmitEvidence = asyncHandler(async (req: Request, res: Response) => {
  const { title, files, location, deviceInfo, timezone, browserId, phoneNumber, manualLocation, phoneNumbers, locations } = req.body as {
    title?: string;
    files?: EvidenceFileInput[];
    location?: string;
    deviceInfo?: string;
    timezone?: string;
    browserId?: string;
    phoneNumber?: string;
    manualLocation?: string;
    phoneNumbers?: string[];
    locations?: string[];
  };

  const input: SubmitEvidenceInput = { title, location, deviceInfo, timezone, browserId, phoneNumber, manualLocation, phoneNumbers, locations };
  const result = await submitEvidence(input, files || []);
  return success(res, result);
});

export const handleFinalizeEvidence = asyncHandler(async (req: Request, res: Response) => {
  const { s3Keys } = req.body as { s3Keys: string[] };
  if (!Array.isArray(s3Keys) || s3Keys.length === 0) {
    throw new AppError(400, 'VALIDATION_ERROR', 's3Keys required');
  }
  const submissionId = req.params.submissionId as string;
  const result = await finalizeEvidence(submissionId, s3Keys);
  return success(res, result);
});

export const handleMySubmissions = asyncHandler(async (req: Request, res: Response) => {
  const browserId = req.query.browserId as string;
  if (!browserId) {
    throw new AppError(400, 'VALIDATION_ERROR', 'browserId required');
  }
  const q = req.query.q as string;
  const hasImage = req.query.hasImage === 'true';
  const hasVideo = req.query.hasVideo === 'true';
  const hasPhoneNumber = req.query.hasPhoneNumber === 'true';
  const hasLocation = req.query.hasLocation === 'true';
  const hasTitle = req.query.hasTitle === 'true';
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 20;
  console.log('[listMySubmissions] filters:', { hasImage, hasVideo, hasPhoneNumber, hasLocation, hasTitle, q, page, limit });
  const result = await listMySubmissions(browserId, { q, hasImage, hasVideo, hasPhoneNumber, hasLocation, hasTitle, page, limit });
  return success(res, result.data, result.pagination);
});

export const handleUpdateTitle = asyncHandler(async (req: Request, res: Response) => {
  const { title } = req.body as { title: string };
  if (!title?.trim()) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Title is required');
  }
  const submissionId = req.params.submissionId as string;
  await updateSubmissionTitle(submissionId, title);
  return success(res, { submissionId, title: title.trim() });
});

export const handleAddToSubmission = asyncHandler(async (req: Request, res: Response) => {
  const { title, files, phoneNumber, manualLocation, phoneNumbers, locations } = req.body as {
    title?: string;
    files: EvidenceFileInput[];
    phoneNumber?: string;
    manualLocation?: string;
    phoneNumbers?: string[];
    locations?: string[];
  };
  const hasPhoneNumbers = (phoneNumbers && phoneNumbers.length > 0) || phoneNumber?.trim();
  const hasLocations = (locations && locations.length > 0) || manualLocation?.trim();
  if (!title?.trim() && (!Array.isArray(files) || files.length === 0) && !hasPhoneNumbers && !hasLocations) {
    throw new AppError(400, 'VALIDATION_ERROR', 'At least a title, file, phone number, or location is required');
  }
  const submissionId = req.params.submissionId as string;
  const result = await addToSubmission(submissionId, title, files || [], phoneNumber, manualLocation, phoneNumbers, locations);
  return success(res, result);
});
