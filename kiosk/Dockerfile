# Use official Node.js image as the base
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json first to leverage Docker layer cache
COPY package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy the rest of the application code
COPY . .

# Build the Next.js app
RUN npm run build

# Remove devDependencies to reduce image size
RUN npm prune --production --legacy-peer-deps

# Expose port 3000
EXPOSE 3000

# Start the Next.js app
CMD ["npm", "start"]