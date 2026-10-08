import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { requireAuth, requireAdmin } from '../../middleware/auth';
import { apiLimiter, submissionLimiter } from '../../middleware/rate-limit';
import {
  CreateTrailSchema,
  UpdateTrailSchema,
  ListTrailsQuerySchema,
} from './trail.schemas';
import {
  handleCreateTrail,
  handleListTrails,
  handleGetTrail,
  handleUpdateTrail,
  handleDeleteTrail,
} from './trail.controller';
import { CreateSubmissionSchema, ListSubmissionsQuerySchema } from '../submission/submission.schemas';
import {
  handleCreateSubmission,
  handleListSubmissions,
} from '../submission/submission.controller';

const router = Router();

// List and create trails
router.get('/', apiLimiter, validate(ListTrailsQuerySchema, 'query'), handleListTrails);
router.post('/', apiLimiter, requireAuth, validate(CreateTrailSchema, 'body'), handleCreateTrail);

// Trail-scoped submission endpoints (literal "submissions" segment, before :slug)
router.post('/:slug/submissions', requireAuth, submissionLimiter, validate(CreateSubmissionSchema, 'body'), handleCreateSubmission);
router.get('/:slug/submissions', apiLimiter, validate(ListSubmissionsQuerySchema, 'query'), handleListSubmissions);

// Trail endpoints (catch-all :slug, must be last)
router.get('/:slug', apiLimiter, handleGetTrail);
router.put('/:slug', apiLimiter, requireAuth, validate(UpdateTrailSchema, 'body'), handleUpdateTrail);
router.delete('/:slug', apiLimiter, requireAuth, requireAdmin, handleDeleteTrail);

export default router;
