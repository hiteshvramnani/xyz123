import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import {
  createSubmission,
  getSubmission,
  updateSubmission,
  listSubmissions,
  listMySubmissions,
} from './submission.service';
import {
  CreateSubmissionInput,
  UpdateSubmissionInput,
  ListSubmissionsQuery,
} from './submission.schemas';

export const handleCreateSubmission = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as CreateSubmissionInput;
  const userId = (req as any).user?.userId;
  const result = await createSubmission(req.params.slug, input, userId);
  return success(res, {
    id: result.id,
    trailId: result.trailId,
    what: result.what,
    where: result.whereField,
    when: result.whenField,
    userId: result.userId,
    mediaCount: 0,
    threadCount: 0,
    createdAt: result.createdAt,
    updatedAt: result.updatedAt,
  });
});

export const handleGetSubmission = asyncHandler(async (req: Request, res: Response) => {
  const submission = await getSubmission(req.params.id);
  return success(res, submission);
});

export const handleUpdateSubmission = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as UpdateSubmissionInput;
  const result = await updateSubmission(req.params.id, input);
  return success(res, result);
});

export const handleListSubmissions = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as ListSubmissionsQuery;
  const result = await listSubmissions(req.params.slug, query);
  return success(res, result.data, result.pagination);
});

export const handleListMySubmissions = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as ListSubmissionsQuery;
  const userId = (req as any).user?.userId;
  if (!userId) {
    throw new Error('Authentication required');
  }
  const result = await listMySubmissions(userId, query);
  return success(res, result.data, result.pagination);
});
