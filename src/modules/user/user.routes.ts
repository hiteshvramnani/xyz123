import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { apiLimiter } from '../../middleware/rate-limit';
import { requireAuth, requireAdmin } from '../../middleware/auth';
import { LoginSchema, CreateUserSchema, UpdateUserStatusSchema } from './user.schemas';
import {
  handleLogin,
  handleCreateUser,
  handleListUsers,
  handleUpdateUserStatus,
  handleDeleteUser,
} from './user.controller';

const router = Router();

// Public
router.post('/login', apiLimiter, validate(LoginSchema, 'body'), handleLogin);

// Admin-only
router.get('/users', apiLimiter, requireAuth, requireAdmin, handleListUsers);
router.post('/users', apiLimiter, requireAuth, requireAdmin, validate(CreateUserSchema, 'body'), handleCreateUser);
router.put('/users/:id/status', apiLimiter, requireAuth, requireAdmin, validate(UpdateUserStatusSchema, 'body'), handleUpdateUserStatus);
router.delete('/users/:id', apiLimiter, requireAuth, requireAdmin, handleDeleteUser);

export default router;
