import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { validate } from '../../middleware/validate';
import { ListSubmissionsQuerySchema } from '../submission/submission.schemas';
import { handleListMySubmissions, handleMySubmissionDetail } from './me.controller';

const router = Router({ mergeParams: true });

router.get('/submissions', requireAuth, validate(ListSubmissionsQuerySchema, 'query'), handleListMySubmissions);
router.get('/submissions/:id', requireAuth, handleMySubmissionDetail);

export default router;
