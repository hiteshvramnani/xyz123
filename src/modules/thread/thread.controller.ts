import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import { createThread, listThreads } from './thread.service';
import { CreateThreadInput, ListThreadsQuery } from './thread.schemas';

export const handleCreateThread = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.userId;
  if (!userId) {
    throw new Error('Authentication required');
  }
  const input = req.body as CreateThreadInput;
  const thread = await createThread(req.params.id, userId, input);
  return success(res, thread);
});

export const handleListThreads = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as ListThreadsQuery;
  const result = await listThreads(req.params.id, query);
  return success(res, result.data, result.pagination);
});
