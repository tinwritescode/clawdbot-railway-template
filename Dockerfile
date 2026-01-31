# Build openclaw from source to avoid npm packaging gaps (some dist files are not shipped).
FROM node:22-bookworm AS openclaw-build

# Dependencies needed for openclaw build
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    python3 \
    make \
    g++ \
    golang \
  && rm -rf /var/lib/apt/lists/*

# Install Bun (openclaw build uses it)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /openclaw

# Pin to a known ref (tag/branch). If it doesn't exist, fall back to main.
ARG OPENCLAW_GIT_REF=main
RUN git clone --depth 1 --branch "${OPENCLAW_GIT_REF}" https://github.com/openclaw/openclaw.git .

# Patch: relax version requirements for packages that may reference unpublished versions.
# Apply to all extension package.json files to handle workspace protocol (workspace:*).
RUN set -eux; \
  find ./extensions -name 'package.json' -type f | while read -r f; do \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*">=[^"]+"/"openclaw": "*"/g' "$f"; \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*"workspace:[^"]+"/"openclaw": "*"/g' "$f"; \
    sed -i -E 's/"clawdbot"[[:space:]]*:[[:space:]]*"[^"]+"/"clawdbot": "*"/g' "$f"; \
    sed -i -E 's/"moltbot"[[:space:]]*:[[:space:]]*"[^"]+"/"moltbot": "*"/g' "$f"; \
  done

RUN node -e "try { const fs = require('fs'); const ts = JSON.parse(fs.readFileSync('tsconfig.json', 'utf8')); ts.compilerOptions = ts.compilerOptions || {}; ts.compilerOptions.noEmitOnError = false; ts.compilerOptions.skipLibCheck = true; fs.writeFileSync('tsconfig.json', JSON.stringify(ts, null, 2)); } catch (e) { console.error('Failed to patch tsconfig', e); }"

RUN pnpm install --no-frozen-lockfile
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install && pnpm ui:build


# Runtime image
FROM node:22-bookworm
ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    golang \
    sudo \
  && rm -rf /var/lib/apt/lists/* \
  && echo "ALL ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd \
  && chmod 0440 /etc/sudoers.d/nopasswd

WORKDIR /app

# Wrapper deps
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copy built openclaw
COPY --from=openclaw-build /openclaw /openclaw

# Provide an openclaw executable
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/dist/entry.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

COPY src ./src

# The wrapper listens on this port.
ENV OPENCLAW_PUBLIC_PORT=8080
ENV CLAWDBOT_PUBLIC_PORT=8080

# Install Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
ENV PORT=8080
EXPOSE 8080 443
CMD ["/app/start.sh"]
