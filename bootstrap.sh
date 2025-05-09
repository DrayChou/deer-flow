#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 创建日志目录
mkdir -p logs

# 设置日志文件名（包含时间戳）
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
LOGPREFIX="deer-flow-$TIMESTAMP"
LOGFILE="$SCRIPT_DIR/logs/$LOGPREFIX.log"

# 定义日志函数，同时输出到控制台和文件
log() {
  echo "$@" | tee -a "$LOGFILE"
}

log "Output will be logged to $LOGFILE"

# 检查前端依赖
if [ ! -d "$SCRIPT_DIR/web/node_modules" ]; then
  log "Web 依赖未安装，正在安装..."
  cd "$SCRIPT_DIR/web"
  pnpm install 2>&1 | tee -a "$LOGFILE"
  cd "$SCRIPT_DIR"
fi

# Start both of DeerFlow's backend and web UI server.
# If the user presses Ctrl+C, kill them both.

if [ "$1" = "--dev" -o "$1" = "-d" -o "$1" = "dev" -o "$1" = "development" ]; then
  log "Starting DeerFlow in [DEVELOPMENT] mode..."
  
  # 使用后台进程并记录PID - 使用统一前缀的日志文件
  cd "$SCRIPT_DIR"
  uv run server.py --reload 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-backend-dev.log" &
  SERVER_PID=$!
  
  cd "$SCRIPT_DIR/web"
  pnpm dev 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-frontend-dev.log" &
  WEB_PID=$!
  
  # 处理中断信号
  trap "log 'Shutting down...'; kill $SERVER_PID $WEB_PID 2>/dev/null; exit" INT TERM
  
  log "Services started. Press Ctrl+C to stop."
  
  # 等待任意子进程结束，并保持日志输出
  wait $SERVER_PID $WEB_PID
else
  log "Starting DeerFlow in [PRODUCTION] mode..."
  
  # 在生产模式下使用后台进程 - 使用统一前缀的日志文件
  cd "$SCRIPT_DIR"
  uv run server.py 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-backend-prod.log" &
  SERVER_PID=$!
  
  # 等待后端服务启动
  log "Waiting for backend service to start..."
  sleep 5
  
  # 检查和创建前端环境变量文件
  cd "$SCRIPT_DIR/web"
  log "Checking and creating frontend environment variables..."
  if [ ! -f ".env.local" ]; then
    cat > .env.local << EOF
# 生产模式环境变量
NEXT_PUBLIC_API_URL=http://localhost:8000
NODE_ENV=production
EOF
    log "Created .env.local file"
  fi
  
  # 清理前端构建目录
  log "Cleaning frontend build directory..."
  if [ -d ".next" ]; then
    rm -rf .next
    log "Cleaned .next directory"
  fi
  
  # 先构建前端项目
  cd "$SCRIPT_DIR/web"
  log "Building frontend..."
  if ! pnpm build 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-frontend-build.log"; then
    log "Frontend build failed! Trying development mode as a fallback..."
    pnpm dev 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-frontend-dev-fallback.log" &
    WEB_PID=$!
    log "Started development mode as a fallback, please access http://localhost:3000"
  else
    log "Frontend built successfully"
    
    # 启动前端服务
    cd "$SCRIPT_DIR/web"
    pnpm start 2>&1 | tee -a "$LOGFILE" "$SCRIPT_DIR/logs/$LOGPREFIX-frontend-prod.log" &
    WEB_PID=$!
  fi
  
  # 处理中断信号
  trap "log 'Shutting down...'; kill $SERVER_PID $WEB_PID 2>/dev/null; exit" INT TERM
  
  log "Production services started. Press Ctrl+C to stop."
  
  # 等待任意子进程结束
  wait $SERVER_PID $WEB_PID
fi
