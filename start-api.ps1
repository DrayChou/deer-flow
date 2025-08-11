# DeerFlow API 启动脚本
# 作者: Claude Code
# 描述: 启动 DeerFlow API 服务器，自动加载 .env 环境变量

# 设置 PowerShell 编码为 UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "🦌 DeerFlow API 启动脚本" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

# 检查当前目录是否为 DeerFlow 项目根目录
if (-not (Test-Path "pyproject.toml") -or -not (Test-Path "main.py")) {
    Write-Host "❌ 错误: 请在 DeerFlow 项目根目录下运行此脚本" -ForegroundColor Red
    Write-Host "   当前目录: $(Get-Location)" -ForegroundColor Yellow
    Read-Host "按任意键退出..."
    exit 1
}

# 检查 .env 文件是否存在
if (-not (Test-Path ".env")) {
    Write-Host "❌ 错误: .env 文件不存在" -ForegroundColor Red
    Write-Host "   请先复制 .env.example 到 .env 并配置相应的 API 密钥" -ForegroundColor Yellow
    Read-Host "按任意键退出..."
    exit 1
}

# 检查 conf.yaml 文件是否存在
if (-not (Test-Path "conf.yaml")) {
    Write-Host "❌ 错误: conf.yaml 文件不存在" -ForegroundColor Red
    Write-Host "   请先复制 conf.yaml.example 到 conf.yaml 并配置 LLM 模型" -ForegroundColor Yellow
    Read-Host "按任意键退出..."
    exit 1
}

Write-Host "✅ 配置文件检查完成" -ForegroundColor Green

# 检查 uv 是否安装
try {
    $uvVersion = uv --version
    Write-Host "✅ UV 版本: $uvVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ 错误: UV 未安装或不在 PATH 中" -ForegroundColor Red
    Write-Host "   请安装 UV: https://docs.astral.sh/uv/getting-started/installation/" -ForegroundColor Yellow
    Read-Host "按任意键退出..."
    exit 1
}

# 函数：读取并设置 .env 环境变量
function Set-EnvVariables {
    Write-Host "📝 加载 .env 环境变量..." -ForegroundColor Blue
    
    $envContent = Get-Content ".env" -Encoding UTF8
    $loadedVars = 0
    
    foreach ($line in $envContent) {
        # 跳过空行和注释
        if ($line -match '^\s*$' -or $line -match '^\s*#') {
            continue
        }
        
        # 解析 KEY=VALUE 格式
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # 移除值两端的引号（如果存在）
            if ($value -match '^".*"$' -or $value -match "^'.*'$") {
                $value = $value.Substring(1, $value.Length - 2)
            }
            
            # 设置环境变量
            [Environment]::SetEnvironmentVariable($key, $value, [EnvironmentVariableTarget]::Process)
            Write-Host "   设置: $key" -ForegroundColor Cyan
            $loadedVars++
        }
    }
    
    Write-Host "✅ 加载了 $loadedVars 个环境变量" -ForegroundColor Green
}

# 函数：检查项目依赖
function Test-Dependencies {
    Write-Host "📦 检查项目依赖..." -ForegroundColor Blue
    
    try {
        # 检查是否有虚拟环境和依赖
        $result = uv run python -c "import sys; print('Python:', sys.version)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Python 环境: $($result -replace 'Python: ', '')" -ForegroundColor Green
        } else {
            Write-Host "⚠️  警告: Python 依赖可能未正确安装" -ForegroundColor Yellow
            Write-Host "   正在同步依赖..." -ForegroundColor Blue
            uv sync
        }
    } catch {
        Write-Host "⚠️  警告: 无法检查 Python 环境，尝试同步依赖..." -ForegroundColor Yellow
        uv sync
    }
}

# 函数：启动 API 服务器
function Start-ApiServer {
    Write-Host "🚀 启动 DeerFlow API 服务器..." -ForegroundColor Blue
    Write-Host "   服务器地址: http://localhost:8701" -ForegroundColor Cyan
    Write-Host "   API 文档: http://localhost:8701/docs" -ForegroundColor Cyan
    Write-Host "   按 Ctrl+C 停止服务器" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor White
    
    try {
        # 使用 uv run 启动服务器，确保在正确的虚拟环境中运行
        uv run uvicorn src.server.app:app --reload --host 0.0.0.0 --port 8701
    } catch {
        Write-Host "❌ 启动失败: $_" -ForegroundColor Red
        Read-Host "按任意键退出..."
        exit 1
    }
}

# 主执行流程
try {
    # 1. 加载环境变量
    Set-EnvVariables
    
    # 2. 检查依赖
    Test-Dependencies
    
    # 3. 启动服务器
    Start-ApiServer
    
} catch {
    Write-Host "❌ 执行过程中发生错误: $_" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit 1
} finally {
    Write-Host "" -ForegroundColor White
    Write-Host "🦌 DeerFlow API 服务器已停止" -ForegroundColor Green
}