import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../../db/client';
import { AppError } from '../../middleware/error-handler';
import { env } from '../../config/env';
import { CreateUserInput } from './user.schemas';

export async function login(username: string, password: string) {
  const user = await prisma.user.findUnique({ where: { username } });
  if (!user) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid username or password');
  }
  if (!user.active) {
    throw new AppError(403, 'ACCOUNT_DISABLED', 'Account has been disabled');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid username or password');
  }

  const token = jwt.sign(
    { userId: user.id, username: user.username, role: user.role },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRY }
  );

  return {
    token,
    user: { id: user.id, username: user.username, role: user.role },
  };
}

export async function createUser(input: CreateUserInput) {
  const existing = await prisma.user.findUnique({ where: { username: input.username } });
  if (existing) {
    throw new AppError(409, 'USERNAME_EXISTS', `Username '${input.username}' already exists`);
  }

  const passwordHash = await bcrypt.hash(input.password, 10);

  const user = await prisma.user.create({
    data: {
      username: input.username,
      passwordHash,
      role: input.role as any,
    },
  });

  return { id: user.id, username: user.username, role: user.role, active: user.active, createdAt: user.createdAt };
}

export async function listUsers() {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      username: true,
      role: true,
      active: true,
      createdAt: true,
      _count: { select: { submissions: true } },
    },
  });

  return users.map((u) => ({
    ...u,
    submissionCount: u._count.submissions,
  }));
}

export async function updateUserStatus(id: string, active: boolean) {
  const user = await prisma.user.findUnique({ where: { id } });
  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const updated = await prisma.user.update({
    where: { id },
    data: { active },
  });

  return { id: updated.id, username: updated.username, role: updated.role, active: updated.active };
}

export async function deleteUser(id: string) {
  const user = await prisma.user.findUnique({ where: { id } });
  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  await prisma.user.delete({ where: { id } });
  return { id };
}
