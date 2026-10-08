import bcrypt from 'bcryptjs';
import prisma from '../src/db/client';

async function main() {
  const existing = await prisma.user.findUnique({ where: { username: 'admin' } });
  if (existing) {
    console.log('Admin user already exists');
    return;
  }

  const passwordHash = await bcrypt.hash('admin123', 10);
  await prisma.user.create({
    data: {
      username: 'admin',
      passwordHash,
      role: 'ADMIN',
    },
  });
  console.log('Created default admin user (username: admin, password: admin123)');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});
