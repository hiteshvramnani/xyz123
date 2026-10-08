import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { apiLimiter } from '../../middleware/rate-limit';
import { CreateTokenSchema, ReporterLoginSchema } from './auth.schemas';
import { createToken, reporterLogin } from './auth.controller';

const router = Router();

router.post('/token', apiLimiter, validate(CreateTokenSchema, 'body'), createToken);
router.post('/reporter', apiLimiter, validate(ReporterLoginSchema, 'body'), reporterLogin);

export default router;
