FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/frontend ./apps/frontend
COPY libs ./libs

# Install dependencies
RUN npm ci

# Build the application
RUN npx nx build frontend --configuration=production

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist/apps/frontend /usr/share/nginx/html

# Copy nginx configuration
COPY apps/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
