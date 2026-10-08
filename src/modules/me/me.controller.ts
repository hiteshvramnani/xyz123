import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { AppError } from '../../middleware/error-handler';
import { asyncHandler } from '../../utils/async-handler';
import { listMySubmissions, getSubmission } from '../submission/submission.service';
import { ListSubmissionsQuery } from '../submission/submission.schemas';

export const handleListMySubmissions = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.userId;
  if (!userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  }
  const query = req.query as unknown as ListSubmissionsQuery;
  const result = await listMySubmissions(userId, query);
  return success(res, result.data, result.pagination);
});

export const handleMySubmissionDetail = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.userId;
  if (!userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
  }
  const submission = await getSubmission(req.params.id);

  // Check ownership
  if ((submission as any).userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not own this submission');
  }

  return success(res, submission);
});
