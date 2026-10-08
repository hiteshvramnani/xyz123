-- AlterTable
ALTER TABLE "threads" ADD COLUMN     "user_id" TEXT,
ALTER COLUMN "reporter_token" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "threads_user_id_idx" ON "threads"("user_id");

-- AddForeignKey
ALTER TABLE "threads" ADD CONSTRAINT "threads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
