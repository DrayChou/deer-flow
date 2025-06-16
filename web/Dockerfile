##### DEPENDENCIES

FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat openssl curl
WORKDIR /app

# 安装 chsrc 工具来统一管理镜像源
RUN curl -L https://gitee.com/RubyMetric/chsrc/releases/download/pre/chsrc-x64-linux -o /usr/local/bin/chsrc && \
    chmod +x /usr/local/bin/chsrc && \
    chsrc set node

# Install dependencies based on the preferred package manager

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

RUN \
    for i in 1 2 3; do \
        if [ -f yarn.lock ]; then yarn --frozen-lockfile && break || sleep 10; \
        elif [ -f package-lock.json ]; then npm ci && break || sleep 10; \
        elif [ -f pnpm-lock.yaml ]; then npm install -g pnpm && pnpm i && break || sleep 10; \
        else echo "Lockfile not found." && exit 1; \
        fi; \
    done

##### BUILDER

FROM node:20-alpine AS builder
WORKDIR /app

# 安装 chsrc 工具来统一管理镜像源
RUN apk add --no-cache curl && \
    curl -L https://gitee.com/RubyMetric/chsrc/releases/download/pre/chsrc-x64-linux -o /usr/local/bin/chsrc && \
    chmod +x /usr/local/bin/chsrc && \
    chsrc set node

ARG NEXT_PUBLIC_API_URL
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1

RUN \
    for i in 1 2 3; do \
        if [ -f yarn.lock ]; then SKIP_ENV_VALIDATION=1 yarn build && break || sleep 10; \
        elif [ -f package-lock.json ]; then SKIP_ENV_VALIDATION=1 npm run build && break || sleep 10; \
        elif [ -f pnpm-lock.yaml ]; then npm install -g pnpm && SKIP_ENV_VALIDATION=1 pnpm run build && break || sleep 10; \
        else echo "Lockfile not found." && exit 1; \
        fi; \
    done

##### RUNNER

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 安装必要的运行时依赖
RUN apk add --no-cache dumb-init

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT=3000

# 使用 dumb-init 作为 init 进程
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
