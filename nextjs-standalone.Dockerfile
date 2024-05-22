# The VERSION arg is used to specify the version of Node.js to use. You can change
# this at build time by passing the --build-arg flag to the docker build command.
ARG VERSION=lts

# Use the official Node.js image with "slim" tag as the base image
# "slim" variants are smaller than the standard Node.js images and don't
# include many unnecessary files and dependencies from the standard distribution
FROM node:${VERSION}-slim AS base
# Enables pnpm and yarn
RUN corepack enable
# Install Bun if a lockfile is present
WORKDIR /app
COPY bun.lockb* ./
RUN if [ -f bun.lockb ]; then npm install -g bun; fi


# Install the necessary dependencies for the application. This is done in a separate
# stage so that the dependencies are cached and not re-installed on every build.
FROM base AS build-deps
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
COPY --from=build-deps /app/node_modules ./node_modules

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1

RUN if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then pnpm run build; \
  elif [ -f bun.lockb ]; then bun run build; \
  else echo "Lockfile not found." && exit 1; \
  fi


# This stage creates the final image that will be used in production. It copies
# the application code and the runtime dependencies from the previous stages.
# Then it sets the user to run the application and the command to start the
# application.
FROM base AS runtime
WORKDIR /app

# Install wget to allow health checks on the container. Then clean up the apt cache to reduce the image size. 
# e.g. `wget -nv -t1 --spider 'http://localhost:8080/health' || exit 1`
RUN apt-get update && apt-get install -y --no-install-recommends wget && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN addgroup --system nonroot && adduser --system --ingroup nonroot nonroot
RUN chown -R nonroot:nonroot /app

COPY --from=builder --chown=nonroot:nonroot /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nonroot:nonroot .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nonroot:nonroot /app/.next/standalone ./
COPY --from=builder --chown=nonroot:nonroot /app/.next/static ./.next/static

USER nonroot:nonroot

# Set the port that the application will run on
ENV PORT=8080
# Expose the port that the application will run on
EXPOSE ${PORT}
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED 1

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD HOSTNAME="0.0.0.0" node server.js
