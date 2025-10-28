FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/backend ./apps/backend
COPY libs ./libs

# Install dependencies
RUN npm install

# Build the application
RUN npx nx build backend

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "dist/apps/backend/main.js"]
