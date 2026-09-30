# Claude Code agentic-mode sandbox.
# Base: Node (for @anthropic-ai/claude-code) on Debian slim for apt availability.
FROM node:24-trixie-slim

ARG GO_VERSION=1.26.5
ARG TASK_VERSION=3.52.0
ARG GOLANGCI_LINT_VERSION=2.12.2
ARG DOCKER_VERSION=29.7.1
ARG BUILDX_VERSION=0.36.1
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
      PATH=/usr/local/go/bin:/home/claude/go/bin:/home/claude/.npm-global/bin:/home/claude/.local/bin:$PATH \
      GOPATH=/home/claude/go \
      GOCACHE=/home/claude/.cache/go-build \
      NPM_CONFIG_PREFIX=/home/claude/.npm-global \
      BASH_ENV=/etc/bash.env


RUN { \
        echo 'export PATH=/usr/local/go/bin:/home/claude/go/bin:/home/claude/.npm-global/bin:/home/claude/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'; \
        echo 'export GOPATH=/home/claude/go'; \
        echo 'export GOCACHE=/home/claude/.cache/go-build'; \
      } > /etc/bash.env


RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git make gcc g++ pkg-config \
        ripgrep fd-find jq less unzip \
        python3 python3-pip \
        openssh-client gnupg \
        procps sudo \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd

# GitHub CLI (user's workflow uses `gh`).
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Go toolchain (project requires /usr/local/go/bin/go per CLAUDE.md).
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) goarch=amd64 ;; \
        arm64) goarch=arm64 ;; \
        *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${goarch}.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    rm /tmp/go.tgz

# Go project tooling, installed to /usr/local/bin so they are on the default
# PATH of any shell, not just one that has sourced /etc/bash.env.
# task: commit_hooks/pre_commit.sh exits 1 without it. golangci-lint: `task lint`.
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    curl -fsSL "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_${arch}.tar.gz" -o /tmp/task.tgz; \
    tar -C /usr/local/bin -xzf /tmp/task.tgz task; \
    rm /tmp/task.tgz; \
    curl -fsSL "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${arch}.tar.gz" -o /tmp/gcl.tgz; \
    tar -C /usr/local/bin --strip-components=1 -xzf /tmp/gcl.tgz "golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${arch}/golangci-lint"; \
    rm /tmp/gcl.tgz; \
    task --version; \
    golangci-lint --version

# Docker CLI + buildx (client only — the e2e suites talk to a daemon over a
# socket mounted from the host, e.g. -v /var/run/docker.sock:/var/run/docker.sock).
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) dockerarch=x86_64; buildxarch=amd64 ;; \
        arm64) dockerarch=aarch64; buildxarch=arm64 ;; \
        *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://download.docker.com/linux/static/stable/${dockerarch}/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz; \
    tar -C /usr/local/bin --strip-components=1 -xzf /tmp/docker.tgz docker/docker; \
    rm /tmp/docker.tgz; \
    mkdir -p /usr/local/lib/docker/cli-plugins; \
    curl -fsSL "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${buildxarch}" \
        -o /usr/local/lib/docker/cli-plugins/docker-buildx; \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx; \
    docker --version

# Create the claude user. Passwordless sudo so ad-hoc `apt-get install` works
# from inside a running container instead of requiring an image rebuild.
RUN useradd --create-home --shell /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude

# Claude Code CLI and the status line renderer it invokes — NPM_CONFIG_PREFIX
# directs install to /home/claude/.npm-global.
RUN npm install -g @anthropic-ai/claude-code ccstatusline \
    && chown -R claude:claude /home/claude/.npm-global

# Map host-style path so absolute paths in ~/.claude/settings.json hooks resolve.
RUN mkdir -p /Users/gulli && ln -s /home/claude/.claude /Users/gulli/.claude

# Prepare workspace and user-writable dirs owned by claude.
RUN mkdir -p /workspace /home/claude/go /home/claude/.cache/go-build /home/claude/.local/bin \
    && chown -R claude:claude /home/claude /workspace

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER claude

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
