# The VERSION arg is used to specify the version of Node.js to use. You can change
# this at build time by passing the --build-arg flag to the docker build command.
ARG VERSION=lts

# Use the official Node.js image with "slim" tag as the base image
# "slim" variants are smaller than the standard Node.js images and don't
# include many unnecessary files and dependencies from the standard distribution
FROM node:${VERSION}-slim AS base
# Enables pnpm and yarn
RUN corepack enable

# Install the necessary dependencies for the application. This is done in a separate
# stage so that the dependencies are cached and not re-installed on every build.
FROM base AS build-deps
WORKDIR /app
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

# Set the NPM_MIRROR build argument to use a custom npm registry mirror.
ARG NPM_MIRROR=
RUN if [ ! -z "${NPM_MIRROR}" ]; then npm config set registry ${NPM_MIRROR}; fi
RUN if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Runtime dependencies are installed in a separate stage so that development
# dependencies are not included in the final image. This reduces the size of the
# final image.
FROM base AS runtime-deps
WORKDIR /app
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

ARG NPM_MIRROR=
RUN if [ ! -z "${NPM_MIRROR}" ]; then npm config set registry ${NPM_MIRROR}; fi
RUN if [ -f yarn.lock ]; then yarn --frozen-lockfile --production; \
  elif [ -f package-lock.json ]; then npm ci --only=production; \
  elif [ -f pnpm-lock.yaml ]; then pnpm i --frozen-lockfile --prod; \
  else echo "Lockfile not found." && exit 1; \
  fi

# This is the final stage of the build process. It copies the application code
# and builds the application.
FROM base AS builder
WORKDIR /app
COPY --from=build-deps /app/node_modules* ./node_modules
COPY . .
ENV NODE_ENV=production
RUN npm run build

FROM base AS runtime
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends wget && apt-get clean && rm -f /var/lib/apt/lists/*_*
# Use a non-root user to run the application. This is a security best practice.
RUN addgroup --system nonroot && adduser --disabled-login --ingroup nonroot nonroot
# Give the non-root user ownership of the application directory and corepack cache
ENV COREPACK_HOME=/app/.cache
RUN mkdir -p /app/.cache
RUN chown -R nonroot:nonroot /app

# Copy the application code and the runtime dependencies from the previous stage.
# You should change "dist" to the directory where your build output is located.
COPY --chown=nonroot:nonroot --from=runtime-deps /app/node_modules* ./node_modules
COPY --chown=nonroot:nonroot --from=builder /app/dist ./dist
COPY --chown=nonroot:nonroot --from=builder /app/package.json ./package.json

USER nonroot:nonroot

# Expose the port that the application will run on
EXPOSE 8080
# Set the port that the application will run on
ENV PORT=8080
ENV NODE_ENV=production
# Change this to the command that starts the production application
CMD npm run preview -- --host 0.0.0.0 --port ${PORT}
