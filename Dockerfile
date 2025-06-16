FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Install uv.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# 安装 chsrc 工具来统一管理镜像源
RUN apt-get update && apt-get install -y curl && \
    curl -L https://gitee.com/RubyMetric/chsrc/releases/download/pre/chsrc-x64-linux -o /usr/local/bin/chsrc && \
    chmod +x /usr/local/bin/chsrc && \
    chsrc set debian && \
    chsrc set python && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the application into the container.
COPY . /app

# Install the application dependencies (环境变量会自动应用)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync

# 设置端口环境变量（可通过构建参数或运行时覆盖）
ARG PORT=8000
ENV PORT=$PORT

EXPOSE $PORT

# Run the application with configurable port.
CMD ["sh", "-c", "uv run python server.py --host 0.0.0.0 --port ${PORT}"]