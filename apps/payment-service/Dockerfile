FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY package*.json pnpm-lock.yaml* ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/payment-service ./apps/payment-service
COPY libs ./libs

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
RUN pnpm exec nx build payment-service

# Expose port
EXPOSE 3002

# Start the application
CMD ["node", "dist/apps/payment-service/main.js"]
