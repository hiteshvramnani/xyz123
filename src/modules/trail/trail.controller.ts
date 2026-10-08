import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import { createTrail, listTrails, getTrailBySlug, updateTrail, deleteTrail } from './trail.service';
import { CreateTrailInput, UpdateTrailInput, ListTrailsQuery } from './trail.schemas';

export const handleCreateTrail = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as CreateTrailInput;
  const userId = (req as any).user?.userId || '';
  const trail = await createTrail(input, userId);
  return success(res, trail);
});

export const handleListTrails = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as ListTrailsQuery;
  const result = await listTrails(query);
  return success(res, result.data, result.pagination);
});

export const handleGetTrail = asyncHandler(async (req: Request, res: Response) => {
  const trail = await getTrailBySlug(req.params.slug);
  return success(res, trail);
});

export const handleUpdateTrail = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as UpdateTrailInput;
  const trail = await updateTrail(req.params.slug, input);
  return success(res, trail);
});

export const handleDeleteTrail = asyncHandler(async (req: Request, res: Response) => {
  const result = await deleteTrail(req.params.slug);
  return success(res, result);
});
