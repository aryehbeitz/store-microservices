FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.base.json ./
COPY nx.json ./

# Copy source code
COPY apps/payment-service ./apps/payment-service
COPY libs ./libs

# Install dependencies
RUN npm install

# Build the application
RUN npx nx build payment-service

# Expose port
EXPOSE 3002

# Start the application
CMD ["node", "dist/apps/payment-service/main.js"]
