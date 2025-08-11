@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM DeerFlow API 启动批处理脚本
REM 作者: Claude Code  
REM 描述: 调用 PowerShell 脚本启动 DeerFlow API 服务器

echo.
echo 🦌 DeerFlow API 启动器
echo =========================
echo.

REM 检查是否在正确的目录
if not exist "pyproject.toml" (
    echo ❌ 错误: 请在 DeerFlow 项目根目录下运行此脚本
    echo    当前目录: %CD%
    pause
    exit /b 1
)

REM 检查 PowerShell 是否可用
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: PowerShell 不可用
    echo    请确保 Windows PowerShell 已安装
    pause
    exit /b 1
)

echo 📝 检测 PowerShell 脚本编码...

REM 检查 start-api.ps1 文件是否存在
if not exist "start-api.ps1" (
    echo ❌ 错误: start-api.ps1 文件不存在
    pause
    exit /b 1
)

REM 检测并转换 PowerShell 脚本编码为 UTF-8 with BOM
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$file = 'start-api.ps1'; " ^
    "if (Test-Path $file) { " ^
    "    $content = Get-Content $file -Raw -Encoding UTF8; " ^
    "    $utf8Bom = New-Object System.Text.UTF8Encoding $true; " ^
    "    [System.IO.File]::WriteAllText((Resolve-Path $file).Path, $content, $utf8Bom); " ^
    "    Write-Host '✅ PowerShell 脚本编码已转换为 UTF-8 with BOM' -ForegroundColor Green; " ^
    "} else { " ^
    "    Write-Host '❌ PowerShell 脚本文件不存在' -ForegroundColor Red; " ^
    "    exit 1; " ^
    "}"

if errorlevel 1 (
    echo ❌ 编码转换失败
    pause
    exit /b 1
)

echo.
echo 🚀 启动 PowerShell 脚本...
echo.

REM 设置 PowerShell 执行策略并运行脚本
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "& { " ^
    "    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; " ^
    "    $OutputEncoding = [System.Text.Encoding]::UTF8; " ^
    "    & '.\start-api.ps1'; " ^
    "}"

REM 保存 PowerShell 的退出代码
set ps_exit_code=%errorlevel%

echo.
if %ps_exit_code% equ 0 (
    echo ✅ API 服务器正常退出
) else (
    echo ❌ API 服务器异常退出 ^(退出代码: %ps_exit_code%^)
)

echo.
pause