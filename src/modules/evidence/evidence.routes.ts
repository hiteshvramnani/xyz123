import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { handleSubmitEvidence, handleFinalizeEvidence, handleMySubmissions, handleAddToSubmission, handleUpdateTitle } from './evidence.controller';
import { SubmitEvidenceSchema } from './evidence.schemas';

const router = Router();

// Public - no auth required
router.get('/my-submissions', handleMySubmissions);
router.post('/', handleSubmitEvidence);
router.post('/:submissionId/finalize', handleFinalizeEvidence);
router.post('/:submissionId/add', handleAddToSubmission);
router.patch('/:submissionId/title', handleUpdateTitle);

export default router;
