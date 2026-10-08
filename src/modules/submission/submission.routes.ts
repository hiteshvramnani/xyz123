import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { apiLimiter, uploadLimiter } from '../../middleware/rate-limit';
import {
  UpdateSubmissionSchema,
} from './submission.schemas';
import {
  handleGetSubmission,
  handleUpdateSubmission,
} from './submission.controller';
import { CreateThreadSchema, ListThreadsQuerySchema } from '../thread/thread.schemas';
import { handleCreateThread, handleListThreads } from '../thread/thread.controller';
import { GetUploadUrlSchema, FinalizeMediaSchema } from '../media/media.schemas';
import {
  handleGetUploadUrl,
  handleFinalizeMedia,
  handleGetDownloadUrl,
  handleDeleteMedia,
} from '../media/media.controller';

const router = Router();

// Media endpoints (static path segment, before :id)
router.post('/:id/media/upload-url', requireAuth, uploadLimiter, validate(GetUploadUrlSchema, 'body'), handleGetUploadUrl);
router.post('/:id/media', requireAuth, uploadLimiter, validate(FinalizeMediaSchema, 'body'), handleFinalizeMedia);

// Thread endpoints (static path segment, before :id)
router.post('/:id/threads', requireAuth, apiLimiter, validate(CreateThreadSchema, 'body'), handleCreateThread);
router.get('/:id/threads', apiLimiter, validate(ListThreadsQuerySchema, 'query'), handleListThreads);

// Submission endpoints (catch-all :id, must be last)
router.get('/:id', apiLimiter, handleGetSubmission);
router.put('/:id', requireAuth, apiLimiter, validate(UpdateSubmissionSchema, 'body'), handleUpdateSubmission);

export default router;
