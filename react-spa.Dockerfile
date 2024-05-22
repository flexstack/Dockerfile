# The VERSION arg is used to specify the version of Node.js to use. You can change
# this at build time by passing the --build-arg flag to the docker build command.
ARG VERSION=lts

# Use the official Node.js image with "slim" tag as the base image
# "slim" variants are smaller than the standard Node.js images and don't
# include many unnecessary files and dependencies from the standard distribution
FROM node:${VERSION}-slim AS base
# Enables pnpm and yarn
RUN corepack enable
WORKDIR /app
COPY bun.lockb* ./
RUN if [ -f bun.lockb ]; then npm install -g bun; fi


# Install the necessary dependencies for the application. This is done in a separate
# stage so that the dependencies are cached and not re-installed on every build.
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* bun.lockb* ./

# Set the NPM_MIRROR build argument to use a custom npm registry mirror.
ARG NPM_MIRROR=
RUN if [ ! -z "${NPM_MIRROR}" ]; then npm config set registry ${NPM_MIRROR}; fi
RUN if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then pnpm i --frozen-lockfile; \
  elif [ -f bun.lockb ]; then bun install; \
  else echo "Lockfile not found." && exit 1; \
  fi


# This is the final stage of the build process. It copies the application code
# and builds the application.
FROM base AS builder
WORKDIR /app
COPY . .
RUN rm -rf node_modules
COPY --from=deps /app/node_modules* ./node_modules
ENV NODE_ENV=production
RUN npm run build


# This stage creates the final image that will be used in production. 
# It runs a static web server to serve the application.
FROM joseluisq/static-web-server:2-debian
# Install wget to allow health checks on the container. Then clean up the apt cache to reduce the image size. 
# e.g. `wget -nv -t1 --spider 'http://localhost:8080/health' || exit 1`
RUN apt-get update && apt-get install -y --no-install-recommends wget && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Copy the application code output from the builder stage to the final image
COPY --from=builder /app/dist /app

# Set the port that the application will run on
ENV PORT=8080
# Expose the port that the application will run on
EXPOSE ${PORT}

# Configure the static web server.
# See: https://static-web-server.net/configuration/environment-variables/#environment-variables
#
# Configure the server to listen on the specified port
ENV SERVER_PORT=${PORT}
# Set the root directory to the location of the application code
ENV SERVER_ROOT=/app
# Enable a health check endpoint
ENV SERVER_HEALTH=true
# When using a SPA, set the fallback page to the index.html file
ENV SERVER_FALLBACK_PAGE=/app/index.html
# Ignore hidden files when serving the application
ENV SERVER_IGNORE_HIDDEN_FILES=true