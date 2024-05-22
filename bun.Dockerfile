# The VERSION arg is used to specify the version of Go to use. You can change
# this at build time by passing the --build-arg flag to the docker build command.
ARG VERSION=1

# Use the official Bun image as the base image
FROM oven/bun:${VERSION} AS base


# Install the necessary dependencies for the application. This is done in a separate
# stage so that the dependencies are cached and not re-installed on every build.
FROM base AS build-deps
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install


# This is the final stage of the build process. It copies the application code
# and builds the application.
FROM base AS builder
WORKDIR /app
COPY --from=build-deps /app/node_modules* ./node_modules
COPY . .
ENV NODE_ENV=production
# Swap the following line with the appropriate build command for your application
RUN bun build index.ts --outfile dist/index.js


# This stage creates the final image that will be used in production. It copies
# the application code and the runtime dependencies from the previous stages.
FROM oven/bun:${VERSION}-alpine AS runtime
WORKDIR /app
# Install ca-certificates to allow the application to make HTTPS requests
RUN apk --update --no-cache add ca-certificates \
  && update-ca-certificates 2>/dev/null || true
# Install wget to allow health checks on the container. Then clean up the apt cache to reduce the image size.
# e.g. `wget -nv -t1 --spider 'http://localhost:8080/health' || exit 1`
RUN apk add --no-cache wget && rm -rf /var/cache/apk/*
RUN addgroup --system nonroot && adduser --system --ingroup nonroot nonroot
RUN chown -R nonroot:nonroot /app

# Copy the application from the build stage to the final stage. 
# You should change "dist" to the directory where your build output is located.
COPY --chown=nonroot:nonroot --from=builder /app/dist ./dist

USER nonroot:nonroot

# Set the port that the application will run on
ENV PORT=8080
# Expose the port that the application will run on
EXPOSE ${PORT}

ENV NODE_ENV=production
# Set the command to start the application. Swap this with the appropriate command for your application.
CMD bun --bun dist/index.js
