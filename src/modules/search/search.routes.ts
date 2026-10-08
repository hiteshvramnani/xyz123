import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { apiLimiter } from '../../middleware/rate-limit';
import { SearchQuerySchema, GeoSearchQuerySchema } from './search.schemas';
import { handleSearch, handleSearchNear } from './search.controller';

const router = Router();

router.get('/', apiLimiter, validate(SearchQuerySchema, 'query'), handleSearch);
router.get('/near', apiLimiter, validate(GeoSearchQuerySchema, 'query'), handleSearchNear);

export default router;
