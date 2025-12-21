FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY package*.json pnpm-lock.yaml* ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/frontend ./apps/frontend
COPY libs ./libs

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
RUN pnpm exec nx build frontend --configuration=production

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist/apps/frontend /usr/share/nginx/html

# Copy nginx configuration
COPY apps/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
