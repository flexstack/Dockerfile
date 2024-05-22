# The VERSION arg is used to specify the version of Go to use. You can change
# this at build time by passing the --build-arg flag to the docker build command.
ARG VERSION=latest
# BUILDPLATFORM matches the platform of the build machine. This is used to set the
# platform for the base image. This is useful when building multi-platform images.
# This is automatically set by Docker when using buildx.
ARG BUILDPLATFORM=linux/amd64

# Use the official Go image as the base image
FROM --platform=${BUILDPLATFORM} golang:${VERSION} AS base
WORKDIR /go/src/app

# Install the necessary dependencies for the application. This is done in a separate
# stage so that the dependencies are cached and not re-installed on every build.
FROM base AS deps 
WORKDIR /go/src/app
COPY go.mod* go.sum* ./
# GOPROXY is used to specify the module proxy to use.
ARG GOPROXY=direct
ENV GOPROXY=${GOPROXY}
RUN if [ -f go.mod ]; then go mod download && go mod tidy; fi


# This is the final stage of the build process. It copies the application code,
#  then builds the application.
FROM deps AS build
WORKDIR /go/src/app

COPY . .
# The PACKAGE arg is used to specify the package to build. You should change this
# to match the package that contains the main function for your application.
ARG PACKAGE=./cmd/app
# OS component from --platform, e.g. linux. This is automatically set by Docker when 
# using buildx.
ARG TARGETOS=linux
# ARCH component from --platform, e.g. amd64. This is automatically set by Docker when 
# using buildx.
ARG TARGETARCH=amd64
# CGO_ENABLED=0 disables the use of cgo
ARG CGO_ENABLED=0
# -trimpath removes the absolute path to the source code in the binary
# -ldflags="-s -w" removes the symbol table and debug information from the binary
RUN CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -trimpath -ldflags="-s -w" -o /go/bin/app "${PACKAGE}"


# This stage creates the final image that will be used in production. It copies
# the compiled application from the previous stage and sets the user to run the
# application. We're using the `alpine:latest` image as the base image to
# reduce the size of the final image.
FROM alpine:latest AS runtime
WORKDIR /app
# Install wget to allow health checks on the container. Then clean up the apt cache to reduce the image size.
# e.g. `wget -nv -t1 --spider 'http://localhost:8080/health' || exit 1`
RUN apt-get update && apt-get install -y --no-install-recommends wget && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Use a non-root user to run the application. This is a security best practice.
RUN addgroup --system nonroot && adduser --system --ingroup nonroot nonroot
RUN chown -R nonroot:nonroot /app

# Copy the application from the build stage to the final stage
COPY --chown=nonroot:nonroot --from=build /go/bin/app .

USER nonroot:nonroot

# Set the port that the application will listen on and the user to run the application
ENV PORT=8080
# Expose the port that the application will run on
EXPOSE ${PORT}
# Run the compiled application
CMD ["/app/app"]
