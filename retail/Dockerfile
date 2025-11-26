# Build stage
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files first
COPY package*.json ./
RUN npm ci

# Accept build argument and set as environment variable BEFORE copying source
ARG VITE_API_URL="https://api.isy.software"
ENV VITE_API_URL=$VITE_API_URL
ENV NODE_ENV=production

# Now copy source and build
COPY . .
RUN npm run build

# Serve stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]