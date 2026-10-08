import { Router } from 'express';
import { apiLimiter } from '../../middleware/rate-limit';
import {
  handleGetDownloadUrl,
  handleDeleteMedia,
  handleStreamMedia,
} from './media.controller';

const router = Router();

router.get('/:id/download-url', apiLimiter, handleGetDownloadUrl);
router.get('/:id/stream', apiLimiter, handleStreamMedia);
router.delete('/:id', apiLimiter, handleDeleteMedia);

export default router;
