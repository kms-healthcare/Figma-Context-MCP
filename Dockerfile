# Figma Context MCP Server Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm@10.10.0

# Copy package files for dependency installation
COPY package.json pnpm-lock.yaml ./

# Install all dependencies (including dev dependencies for build)
RUN pnpm install --frozen-lockfile

# Copy source code and configuration files
COPY src/ ./src/
COPY tsconfig.json ./
COPY tsup.config.ts ./

# Build the application
RUN pnpm build

# Production stage
FROM node:18-alpine AS production

# Set working directory
WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm@10.10.0

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install only production dependencies
RUN pnpm install --frozen-lockfile --prod

# Copy built application from build stage
COPY --from=builder /app/dist ./dist

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S figma -u 1001 -G nodejs

# Change ownership of the app directory to the nodejs user
RUN chown -R figma:nodejs /app

# Switch to non-root user
USER figma

# Expose the default port (can be overridden with PORT environment variable)
EXPOSE 3333

# Health check to ensure the service is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD if [ "$NODE_ENV" = "cli" ]; then exit 0; else node -e "require('http').get('http://localhost:3333', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"; fi

# Default environment variables
ENV NODE_ENV=production
ENV PORT=3333
ENV OUTPUT_FORMAT=yaml
ENV SKIP_IMAGE_DOWNLOADS=false

# Entry point - supports both STDIO and HTTP modes
# For STDIO mode: docker run -e NODE_ENV=cli your-image
# For HTTP mode: docker run -p 3333:3333 your-image
CMD ["node", "dist/cli.js"]
