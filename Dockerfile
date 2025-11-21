# syntax=docker/dockerfile:1.6

# Base build stage installs dependencies
FROM node:22.13-slim AS base
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY . .

# Lightweight production image.
FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=base /app /app
EXPOSE 3000
CMD ["npm", "start"]
