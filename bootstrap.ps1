# DeerFlow 启动脚本 - PowerShell 版本

# 使用开关参数和别名来处理不同的开发模式标志
param(
    [Parameter()]
    [Alias("d", "dev", "development")]
    [switch]$DevMode
)

# 设置项目根目录为脚本所在的目录
$ProjectRoot = $PSScriptRoot
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Location).Path
}

# 创建日志目录
$logDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# 设置日志文件名（包含时间戳）
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$logPrefix = "deer-flow-$timestamp"
$logFile = Join-Path $logDir "$logPrefix.log"

# 创建日志函数（同时输出到控制台和文件）
function Write-TeeLog {
    param([string]$Message)
    Write-Host $Message
    $Message | Out-File -FilePath $logFile -Append
}

Write-TeeLog "日志文件位置: $logFile"

# 检查前端依赖
$webDir = Join-Path $ProjectRoot "web"
$nodeModulesDir = Join-Path $webDir "node_modules"
if (-not (Test-Path $nodeModulesDir)) {
    Write-TeeLog "Web 依赖未安装，正在安装..."
    Push-Location $webDir
    & pnpm install | Tee-Object -FilePath $logFile -Append
    Pop-Location
}

# 检查是否有未处理的参数 (用于兼容使用 --dev 和其他形式传参)
$isDevMode = $DevMode -or $args -contains "--dev" -or $args -contains "-d" -or $args -contains "dev" -or $args -contains "development"

Write-TeeLog "开发模式判断结果: $isDevMode"

# 检查是否为开发模式
if ($isDevMode) {
    Write-TeeLog "Starting DeerFlow in [DEVELOPMENT] mode..."
    
    # 非阻塞方式启动后端服务 - 使用统一前缀
    Push-Location $ProjectRoot
    Start-Process -FilePath "uv" -ArgumentList "run", "server.py", "--reload" `
        -RedirectStandardOutput (Join-Path $logDir "$logPrefix-backend.log") `
        -RedirectStandardError (Join-Path $logDir "$logPrefix-backend-error.log") -NoNewWindow
    Pop-Location
    
    # 非阻塞方式启动前端服务 - 使用统一前缀
    Push-Location $webDir
    Start-Process -FilePath "pnpm" -ArgumentList "dev" `
        -RedirectStandardOutput (Join-Path $logDir "$logPrefix-frontend.log") `
        -RedirectStandardError (Join-Path $logDir "$logPrefix-frontend-error.log") -NoNewWindow
    Pop-Location
    
    # 创建监视日志文件的函数
    function Watch-LogFile {
        param([string]$FilePath, [string]$Prefix)
        
        if (Test-Path $FilePath) {
            $lastSize = 0
            $currentSize = (Get-Item $FilePath).Length
            
            if ($currentSize -gt $lastSize) {
                $content = Get-Content $FilePath -Tail 10
                foreach ($line in $content) {
                    Write-TeeLog "[$Prefix] $line"
                }
                $lastSize = $currentSize
            }
        }
    }
    
    Write-TeeLog "服务已启动。实时监控输出中，按 Ctrl+C 退出..."
    
    try {
        while ($true) {
            # 监控后端日志 - 使用新的文件路径
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-backend.log") -Prefix "BACKEND"
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-backend-error.log") -Prefix "BACKEND ERROR"
            
            # 监控前端日志 - 使用新的文件路径
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-frontend.log") -Prefix "FRONTEND"
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-frontend-error.log") -Prefix "FRONTEND ERROR"
            
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-TeeLog "捕获到中断，正在关闭服务..."
    }
    finally {
        # 关闭服务
        Get-Process -Name "uv" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$webDir*" } | Stop-Process -Force
        Write-TeeLog "服务已关闭"
    }
} else {
    # 生产模式下运行 - 修改为非阻塞方式
    Write-TeeLog "Starting DeerFlow in [PRODUCTION] mode..."
    
    # 非阻塞方式启动后端服务 - 使用统一前缀
    Push-Location $ProjectRoot
    Start-Process -FilePath "uv" -ArgumentList "run", "server.py" `
        -RedirectStandardOutput (Join-Path $logDir "$logPrefix-backend-prod.log") `
        -RedirectStandardError (Join-Path $logDir "$logPrefix-backend-prod-error.log") -NoNewWindow
    Pop-Location
    
    # 等待后端服务启动完成
    Write-TeeLog "等待后端服务启动..."
    Start-Sleep -Seconds 5
    
    # 创建前端环境变量文件 - 确保设置了必要的生产环境变量
    Push-Location $webDir
    Write-TeeLog "检查和创建前端环境变量..."
    $envFile = Join-Path $webDir ".env.local"
    if (-not (Test-Path $envFile)) {
        @"
# 生产模式环境变量
NEXT_PUBLIC_API_URL=http://localhost:8000
NODE_ENV=production
"@ | Out-File -FilePath $envFile -Encoding utf8
        Write-TeeLog "已创建 .env.local 文件"
    }
    
    # 先清理前端构建目录，避免缓存问题
    Write-TeeLog "清理前端构建目录..."
    if (Test-Path (Join-Path $webDir ".next")) {
        Remove-Item -Recurse -Force (Join-Path $webDir ".next") -ErrorAction SilentlyContinue
        Write-TeeLog "已清理 .next 目录"
    }
    
    # 构建前端项目，添加详细日志
    Write-TeeLog "构建前端项目..."
    $buildOutput = & pnpm build 2>&1
    $buildOutput | Out-File -FilePath (Join-Path $logDir "$logPrefix-frontend-build.log") -Append
    $buildSuccess = $?
    
    # 检查构建是否成功
    if (-not $buildSuccess) {
        Write-TeeLog "前端构建失败！请检查错误信息:"
        $buildOutput | ForEach-Object { Write-TeeLog $_ }
        
        # 尝试使用开发模式作为备选方案
        Write-TeeLog "尝试使用开发模式作为备选方案..."
        $devProcess = Start-Process -FilePath "pnpm" -ArgumentList "dev" `
            -RedirectStandardOutput (Join-Path $logDir "$logPrefix-frontend-dev-fallback.log") `
            -RedirectStandardError (Join-Path $logDir "$logPrefix-frontend-dev-fallback-error.log") `
            -NoNewWindow -PassThru
        Write-TeeLog "已启动开发模式作为备选方案，请访问 http://localhost:3000"
    } else {
        Write-TeeLog "前端构建成功，准备启动生产服务..."
        
        # 定义要尝试的不同包管理器命令
        $packageManagers = @(
            @{Cmd = "pnpm.cmd"; Args = @("start")},
            @{Cmd = "npx.cmd"; Args = @("pnpm", "start")},
            @{Cmd = "npm.cmd"; Args = @("run", "start")},
            @{Cmd = "yarn.cmd"; Args = @("start")}
        )
        
        $success = $false
        foreach ($pm in $packageManagers) {
            if (Get-Command $pm.Cmd -ErrorAction SilentlyContinue) {
                Write-TeeLog "使用 $($pm.Cmd) 启动前端..."
                try {
                    $processArgs = @{
                        FilePath = $pm.Cmd
                        ArgumentList = $pm.Args
                        RedirectStandardOutput = (Join-Path $logDir "$logPrefix-frontend-prod.log")
                        RedirectStandardError = (Join-Path $logDir "$logPrefix-frontend-prod-error.log")
                        NoNewWindow = $true
                        ErrorAction = "Stop"
                    }
                    Start-Process @processArgs
                    $success = $true
                    break
                }
                catch {
                    Write-TeeLog "使用 $($pm.Cmd) 启动失败: $_"
                }
            }
        }
        
        if (-not $success) {
            Write-TeeLog "警告: 无法使用任何包管理器启动前端。请手动执行以下命令:"
            Write-TeeLog "cd $webDir && pnpm start"
        }
    }
    
    Pop-Location
    
    # 创建监视日志文件的函数
    function Watch-LogFile {
        param([string]$FilePath, [string]$Prefix)
        
        if (Test-Path $FilePath) {
            $lastSize = (Get-Item $FilePath).Length
            $currentSize = (Get-Item $FilePath).Length
            
            if ($currentSize -gt $lastSize) {
                $content = Get-Content $FilePath -Tail 10
                foreach ($line in $content) {
                    Write-TeeLog "[$Prefix] $line"
                }
            }
        }
    }
    
    Write-TeeLog "生产模式服务已启动。实时监控输出中，按 Ctrl+C 退出..."
    
    try {
        while ($true) {
            # 监控后端日志 - 使用新的文件路径
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-backend-prod.log") -Prefix "BACKEND"
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-backend-prod-error.log") -Prefix "BACKEND ERROR"
            
            # 监控前端日志 - 使用新的文件路径
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-frontend-prod.log") -Prefix "FRONTEND"
            Watch-LogFile -FilePath (Join-Path $logDir "$logPrefix-frontend-prod-error.log") -Prefix "FRONTEND ERROR"
            
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-TeeLog "捕获到中断，正在关闭服务..."
    }
    finally {
        # 关闭服务
        Get-Process -Name "uv" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$webDir*" } | Stop-Process -Force
        Write-TeeLog "服务已关闭"
    }
}
