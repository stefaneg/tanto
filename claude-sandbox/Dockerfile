# Claude Code agentic-mode sandbox.
# Base: Node (for @anthropic-ai/claude-code) on Debian slim for apt availability.
FROM node:20-bookworm-slim

ARG GO_VERSION=1.23.4
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/go/bin:/home/claude/go/bin:/home/claude/.npm-global/bin:/home/claude/.local/bin:$PATH \
    GOPATH=/home/claude/go \
    GOCACHE=/home/claude/.cache/go-build \
    NPM_CONFIG_PREFIX=/home/claude/.npm-global

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git make gcc g++ pkg-config \
        ripgrep fd-find jq less unzip \
        python3 python3-pip \
        openssh-client gnupg \
    && rm -rf /var/lib/apt/lists/*

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

# Create the claude user.
RUN useradd --create-home --shell /bin/bash claude

# Claude Code CLI — NPM_CONFIG_PREFIX directs install to /home/claude/.npm-global.
RUN npm install -g @anthropic-ai/claude-code \
    && chown -R claude:claude /home/claude/.npm-global

# nwave-ai
# Install uv globally so it's available across build layers and users.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Map host-style path so absolute paths in ~/.claude/settings.json hooks resolve.
RUN mkdir -p /Users/gulli && ln -s /home/claude/.claude /Users/gulli/.claude

# Prepare workspace and user-writable dirs owned by claude.
RUN mkdir -p /workspace /home/claude/go /home/claude/.cache/go-build /home/claude/.local/bin \
    && chown -R claude:claude /home/claude /workspace

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER claude
RUN uv tool install nwave-ai
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
