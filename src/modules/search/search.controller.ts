import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import { searchSubmissions, searchNear } from './search.service';
import { SearchQuery, GeoSearchQuery } from './search.schemas';

export const handleSearch = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as SearchQuery;
  const result = await searchSubmissions(query);
  return success(res, result.data, result.pagination);
});

export const handleSearchNear = asyncHandler(async (req: Request, res: Response) => {
  const query = req.query as unknown as GeoSearchQuery;
  const result = await searchNear(query);
  return success(res, result.data, result.pagination);
});
