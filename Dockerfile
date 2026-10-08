FROM node:20-slim AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false

COPY tsconfig.json tsconfig.build.json prisma/ ./
COPY src/ ./src/

RUN npx prisma generate
RUN npm run build

FROM node:20-slim

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY prisma/ ./prisma/

RUN npx prisma generate --no-hints

EXPOSE 3000
CMD ["node", "dist/server.js"]
