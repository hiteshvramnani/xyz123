import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import { generateServiceToken, loginReporter } from './auth.service';
import { CreateTokenInput, ReporterLoginInput } from './auth.schemas';

export const createToken = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as CreateTokenInput;
  const result = await generateServiceToken(input);
  return success(res, result);
});

export const reporterLogin = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as ReporterLoginInput;
  const result = await loginReporter(input);
  return success(res, result);
});
