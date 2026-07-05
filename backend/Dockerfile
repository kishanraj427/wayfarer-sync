# Use the official Bun image
FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
FROM base AS install
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# Copy source and build
FROM base AS release
COPY --from=install /app/node_modules ./node_modules
COPY . .

# Generate Prisma client
RUN bunx prisma generate

# Expose the port
EXPOSE 3000

# Run migrations then start the server
CMD ["sh", "-c", "bunx prisma migrate deploy && bun src/index.ts"]
