const BASE = '/api/v1';

type ApiResponse = { success: boolean; data: any; error?: any; pagination?: any };

async function request(path: string, options?: RequestInit): Promise<ApiResponse> {
  const token = localStorage.getItem('token');
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE}${path}`, { ...options, headers: { ...headers, ...(options?.headers || {}) } });
  const data = await res.json();
  if (!data.success) throw new Error(data.error?.message || 'Request failed');
  return data;
}

function normalize(s: any) {
  if (!s) return s;
  return { ...s, where: s.whereField || s.where, when: s.whenField || s.when };
}

// Auth
export async function login(username: string, password: string) {
  const r = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
  localStorage.setItem('token', r.data.token);
  localStorage.setItem('username', r.data.user.username);
  localStorage.setItem('role', r.data.user.role);
  return r.data;
}

export function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('username');
  localStorage.removeItem('role');
}

export function getCurrentUser() {
  const username = localStorage.getItem('username');
  const role = localStorage.getItem('role');
  return username ? { username, role } : null;
}

export function isAdmin() {
  return localStorage.getItem('role') === 'ADMIN';
}

// Users (admin only)
export async function createUser(username: string, password: string, role: 'ADMIN' | 'USER') {
  return request('/auth/users', {
    method: 'POST',
    body: JSON.stringify({ username, password, role }),
  });
}

export async function listUsers() {
  return request('/auth/users');
}

export async function updateUserStatus(id: string, active: boolean) {
  return request(`/auth/users/${id}/status`, {
    method: 'PUT',
    body: JSON.stringify({ active }),
  });
}

export async function deleteUser(id: string) {
  return request(`/auth/users/${id}`, { method: 'DELETE' });
}

// Trails
export async function createTrail(name: string, description?: string, tags?: string[]) {
  return request('/trails', {
    method: 'POST',
    body: JSON.stringify({ name, description, tags: tags || [] }),
  });
}

export async function listTrails(cursor?: string) {
  const params = cursor ? `?cursor=${cursor}` : '';
  return request(`/trails${params}`);
}

export async function getTrail(slug: string) {
  return request(`/trails/${slug}`);
}

export async function deleteTrail(slug: string) {
  return request(`/trails/${slug}`, { method: 'DELETE' });
}

// Submissions
export async function createSubmission(trailSlug: string, what: string, where: string, when: string) {
  const r = await request(`/trails/${trailSlug}/submissions`, {
    method: 'POST',
    body: JSON.stringify({ what, where, when }),
  });
  if (r.data) r.data = normalize(r.data);
  return r;
}

export async function listSubmissions(trailSlug: string, cursor?: string) {
  const params = cursor ? `?cursor=${cursor}` : '';
  const r = await request(`/trails/${trailSlug}/submissions${params}`);
  const data = Array.isArray(r.data) ? r.data.map(normalize) : r.data;
  return { ...r, data };
}

export async function getSubmission(id: string) {
  const r = await request(`/submissions/${id}`);
  const data = normalize(r.data);
  return { ...r, data };
}

// User portal — my submissions
export async function mySubmissions() {
  const r = await request('/me/submissions');
  const data = Array.isArray(r.data) ? r.data.map(normalize) : r.data;
  return { ...r, data };
}

// Threads
export async function createThread(submissionId: string, content: string, locationText?: string) {
  return request(`/submissions/${submissionId}/threads`, {
    method: 'POST',
    body: JSON.stringify({ content, locationText }),
  });
}

export async function listThreads(submissionId: string, cursor?: string) {
  const params = cursor ? `?cursor=${cursor}` : '';
  return request(`/submissions/${submissionId}/threads${params}`);
}

// Search
export async function search(query: string) {
  return request(`/search?q=${encodeURIComponent(query)}`);
}

// Evidence (public)
export async function submitEvidence(data: {
  title?: string;
  files?: Array<{ mimeType: string; fileSizeBytes: number; fileName: string }>;
  location?: string;
  deviceInfo?: string;
  timezone?: string;
  browserId?: string;
  phoneNumber?: string;
  manualLocation?: string;
}) {
  return request('/evidence', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export function getBrowserId(): string {
  let id = localStorage.getItem('browserId');
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem('browserId', id);
  }
  return id;
}

export async function listMySubmissions(browserId: string) {
  const r = await request(`/evidence/my-submissions?browserId=${encodeURIComponent(browserId)}`);
  const data = Array.isArray(r.data) ? r.data.map(normalize) : r.data;
  return { ...r, data };
}

export async function getMediaDownloadUrl(mediaId: string) {
  return request(`/media/${mediaId}/download-url`);
}

export async function addToSubmission(submissionId: string, title: string | undefined, files: Array<{ mimeType: string; fileSizeBytes: number; fileName: string }>, phoneNumber?: string, manualLocation?: string) {
  return request(`/evidence/${submissionId}/add`, {
    method: 'POST',
    body: JSON.stringify({ title, files, phoneNumber, manualLocation }),
  });
}

export async function finalizeEvidence(submissionId: string, s3Keys: string[]) {
  return request(`/evidence/${submissionId}/finalize`, {
    method: 'POST',
    body: JSON.stringify({ s3Keys }),
  });
}

// Upload file via presigned URL
export async function uploadToS3(uploadUrl: string, file: File) {
  const res = await fetch(uploadUrl, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': file.type },
  });
  if (!res.ok) throw new Error('File upload failed');
}
