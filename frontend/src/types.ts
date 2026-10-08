export interface Trail {
  id: string;
  slug: string;
  name: string;
  description?: string;
  tags: string[];
  createdAt: string;
  submissionCount?: number;
}

export interface Submission {
  id: string;
  trailId: string;
  what: string;
  where: string;
  when: string;
  sourceChain?: string;
  reporterToken?: string;
  submittedBy?: string;
  createdAt: string;
  mediaCount?: number;
  threadCount?: number;
  trailSlug?: string;
  trailName?: string;
  media?: any[];
  where_field?: string;
}

export interface Thread {
  id: string;
  submissionId: string;
  content: string;
  locationText?: string;
  createdAt: string;
}

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  pagination?: {
    nextCursor?: string;
    hasMore: boolean;
  };
}

export type View =
  | { type: 'trails' }
  | { type: 'trail'; slug: string }
  | { type: 'submission'; id: string }
  | { type: 'search'; query: string }
  | { type: 'new-trail' };
