# Dockerfile

A collection of *high quality* Dockerfiles for different programming languages and frameworks.

[Check out `new-dockerfile`](https://github.com/flexstack/new-dockerfile) for a tool to generate Dockerfiles for your projects.

## FlexStack ♡ Docker

At FlexStack we love the humble Dockerfile. They offer unparalleled flexibility (😉) and control, allowing you to specify 
exactly how your environment should be built, from the operating system up. This precision ensures that your applications 
run exactly as intended, in any environment, which is critical for reliable deployments.

Unfortunately, Dockerfiles can be boring to write and maintain. They're often verbose, repetitive, and sometimes require a lot of 
boilerplate code. They can also be difficult to get right in terms of security, build performance, and best practices. This repository 
aims to provide a collection of example Dockerfiles for different programming languages and frameworks, to help you get started with your 
own projects.

We hope you find them useful! If you have any suggestions or improvements, please feel free to open an issue or pull request.

## Usage

Each Dockerfile in this repository is designed to be a starting point for your own projects. They are intended to be copied and modified
to suit your specific requirements. To use a Dockerfile, simply copy it into your project directory and build it using the `docker build` command.

For example, to build the `nodejs.Dockerfile`:

```bash
docker build -t my-nodejs-app -f nodejs.Dockerfile .
```

## Languages and Frameworks

The following Dockerfiles are available in this repository:

- [Bun](bun.Dockerfile) - A Bun Dockerfile with multi-stage build. We tested this with a [Bun](https://bun.sh/) "Hello world" server.
- [Golang](golang.Dockerfile) - A minimal Go Dockerfile with multi-stage build that works with Go modules. We tested this in a [Fiber project](https://gofiber.io/).
- [Next.js](nextjs.Dockerfile) - A Next.js Dockerfile with multi-stage build that works with Yarn, PNPM, Bun, or NPM package managers. We tested this in a [Next.js project](https://nextjs.org/). This Dockerfile is designed to run the Next.js server in production mode.
- [Next.js w/ standalone output](nextjs-standalone.Dockerfile) - A Next.js Dockerfile with multi-stage build that works with Yarn, PNPM, Bun, or NPM package managers. We tested this in a [Next.js project](https://nextjs.org/). This Dockerfile is designed to build the Next.js project and served with a [`standalone` output](https://nextjs.org/docs/pages/api-reference/next-config-js/output#automatically-copying-traced-files).
- [Node.js](nodejs.Dockerfile) - A simple Node.js Dockerfile with multi-stage build that works with Yarn, PNPM, or NPM package managers. We tested this in an [Astro project](https://docs.astro.build/en/getting-started/).

## Contributing

If you have a Dockerfile that you would like to contribute, please feel free to open a pull request. We welcome contributions for any programming language or framework, as long as they follow the guidelines below:

- Should be well-commented and easy to understand.
- Should be as minimal as possible, while still being functional.
- Should follow best practices for security (non-root user, etc.), performance (cached stages), and maintainability.
- Should be tested and working with the latest version of the language or framework.
- Should use multi-stage builds where appropriate.
- Should be based on an official Docker image where possible.

Read the [CONTRIBUTING.md](CONTRIBUTING.md) file for more information on how to contribute.

## License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

