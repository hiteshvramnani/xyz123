-- CreateEnum
CREATE TYPE "Urgency" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

-- CreateEnum
CREATE TYPE "MediaType" AS ENUM ('IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT', 'SCREENSHOT');

-- CreateTable
CREATE TABLE "trails" (
    "id" TEXT NOT NULL,
    "slug_text" TEXT NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "created_by_token" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trails_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "submissions" (
    "id" TEXT NOT NULL,
    "trail_id" TEXT NOT NULL,
    "what" TEXT NOT NULL,
    "where_field" TEXT NOT NULL,
    "when_field" TIMESTAMP(3) NOT NULL,
    "time_window_start" TIMESTAMP(3),
    "time_window_end" TIMESTAMP(3),
    "urgency" "Urgency",
    "source_chain" TEXT,
    "time_lag_minutes" INTEGER,
    "location_context" TEXT,
    "reporter_token" VARCHAR(64) NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "submissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "media" (
    "id" TEXT NOT NULL,
    "submission_id" TEXT NOT NULL,
    "mediaType" "MediaType" NOT NULL,
    "s3_key" VARCHAR(500) NOT NULL,
    "mime_type" VARCHAR(100) NOT NULL,
    "file_size_bytes" BIGINT NOT NULL,
    "thumbnail_s3_key" VARCHAR(500),
    "caption" TEXT,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "threads" (
    "id" TEXT NOT NULL,
    "submission_id" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "location_text" TEXT,
    "metadata" JSONB,
    "reporter_token" VARCHAR(64) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "threads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "trails_slug_text_key" ON "trails"("slug_text");

-- CreateIndex
CREATE INDEX "trails_slug_text_idx" ON "trails"("slug_text");

-- CreateIndex
CREATE INDEX "trails_tags_idx" ON "trails"("tags");

-- CreateIndex
CREATE INDEX "submissions_trail_id_idx" ON "submissions"("trail_id");

-- CreateIndex
CREATE INDEX "submissions_reporter_token_idx" ON "submissions"("reporter_token");

-- CreateIndex
CREATE INDEX "submissions_when_field_idx" ON "submissions"("when_field");

-- CreateIndex
CREATE INDEX "submissions_createdAt_idx" ON "submissions"("createdAt");

-- CreateIndex
CREATE INDEX "submissions_urgency_idx" ON "submissions"("urgency");

-- CreateIndex
CREATE INDEX "media_submission_id_idx" ON "media"("submission_id");

-- CreateIndex
CREATE INDEX "media_mediaType_idx" ON "media"("mediaType");

-- CreateIndex
CREATE INDEX "threads_submission_id_idx" ON "threads"("submission_id");

-- CreateIndex
CREATE INDEX "threads_reporter_token_idx" ON "threads"("reporter_token");

-- CreateIndex
CREATE INDEX "threads_createdAt_idx" ON "threads"("createdAt");

-- AddForeignKey
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_trail_id_fkey" FOREIGN KEY ("trail_id") REFERENCES "trails"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media" ADD CONSTRAINT "media_submission_id_fkey" FOREIGN KEY ("submission_id") REFERENCES "submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "threads" ADD CONSTRAINT "threads_submission_id_fkey" FOREIGN KEY ("submission_id") REFERENCES "submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
