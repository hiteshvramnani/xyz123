import { Request, Response } from 'express';
import { success } from '../../utils/response';
import { asyncHandler } from '../../utils/async-handler';
import { login, createUser, listUsers, updateUserStatus, deleteUser } from './user.service';
import { CreateUserInput } from './user.schemas';

export const handleLogin = asyncHandler(async (req: Request, res: Response) => {
  const { username, password } = req.body as { username: string; password: string };
  const result = await login(username, password);
  return success(res, result);
});

export const handleCreateUser = asyncHandler(async (req: Request, res: Response) => {
  const input = req.body as CreateUserInput;
  const result = await createUser(input);
  return success(res, result);
});

export const handleListUsers = asyncHandler(async (_req: Request, res: Response) => {
  const users = await listUsers();
  return success(res, users);
});

export const handleUpdateUserStatus = asyncHandler(async (req: Request, res: Response) => {
  const active = (req.body as { active: boolean }).active;
  const id = req.params.id as string;
  const result = await updateUserStatus(id, active);
  return success(res, result);
});

export const handleDeleteUser = asyncHandler(async (req: Request, res: Response) => {
  const id = req.params.id as string;
  await deleteUser(id);
  return success(res, { message: 'User deleted' });
});
