FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY package*.json pnpm-lock.yaml* ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/backend ./apps/backend
COPY libs ./libs

# Install dependencies
RUN pnpm ci

# Build the application
RUN pnpm exec nx build backend

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "dist/apps/backend/main.js"]
