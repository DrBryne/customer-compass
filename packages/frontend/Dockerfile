# Stage 1: Build the React application
FROM node:18-alpine AS builder

# Set the working directory
WORKDIR /app

# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application files
COPY . .

# Build the application for production
RUN npm run build

# ---_---

# Stage 2: Serve the application using Nginx
FROM nginx:1.25-alpine

# Copy the built static files from the builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Copy a custom Nginx configuration file
# This is useful for routing all requests to index.html for single-page applications
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80 for the Nginx server
EXPOSE 80

# Command to start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
