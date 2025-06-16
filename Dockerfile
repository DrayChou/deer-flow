FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Install uv.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# 接收构建参数
ARG UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple/
ARG UV_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn

# 设置环境变量
ENV UV_INDEX_URL=$UV_INDEX_URL
ENV UV_TRUSTED_HOST=$UV_TRUSTED_HOST
ENV UV_HTTP_TIMEOUT=300

# 配置 uv 使用镜像源
RUN uv config --global index-url $UV_INDEX_URL && \
    uv config --global trusted-host $UV_TRUSTED_HOST

# 先尝试更新锁文件（如果需要）
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv lock --locked || uv lock

# Pre-cache the application dependencies.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --no-install-project

# Copy the application into the container.
COPY . /app

# Install the application dependencies.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync

# 设置端口环境变量（可通过构建参数或运行时覆盖）
ARG PORT=8000
ENV PORT=$PORT

EXPOSE $PORT

# Run the application with configurable port.
CMD ["sh", "-c", "uv run python server.py --host 0.0.0.0 --port ${PORT}"]