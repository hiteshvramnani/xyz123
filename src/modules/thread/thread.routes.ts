import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { apiLimiter } from '../../middleware/rate-limit';
import { CreateThreadSchema, ListThreadsQuerySchema } from './thread.schemas';
import { handleCreateThread, handleListThreads } from './thread.controller';

const router = Router();

router.post('/:submissionId/threads', apiLimiter, validate(CreateThreadSchema, 'body'), handleCreateThread);
router.get('/:submissionId/threads', apiLimiter, validate(ListThreadsQuerySchema, 'query'), handleListThreads);

export default router;
