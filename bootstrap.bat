REM filepath: e:\git\deer-flow\bootstrap.bat
@echo off
SETLOCAL ENABLEEXTENSIONS

REM 创建日志目录
if not exist logs mkdir logs

REM 设置日志文件名（包含时间戳）
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set DATE=%%c-%%a-%%b)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (set TIME=%%a%%b)
SET LOGPREFIX=deer-flow-%DATE%-%TIME%
SET LOGFILE=%~dp0logs\%LOGPREFIX%.log

REM 输出重定向说明
echo Output will be logged to %LOGFILE%
echo Output will be logged to %LOGFILE% > %LOGFILE%

REM 保存当前目录
SET PROJECT_ROOT=%~dp0

REM 检查 web 目录的 node_modules 是否存在
IF NOT EXIST "%PROJECT_ROOT%web\node_modules" (
    echo Web 依赖未安装，正在安装...
    echo Web 依赖未安装，正在安装... >> %LOGFILE%
    cd "%PROJECT_ROOT%web"
    call pnpm install >> %LOGFILE% 2>&1
    cd "%PROJECT_ROOT%"
)

REM Check if argument is dev mode
SET MODE=%1
IF "%MODE%"=="--dev" GOTO DEV
IF "%MODE%"=="-d" GOTO DEV
IF "%MODE%"=="dev" GOTO DEV
IF "%MODE%"=="development" GOTO DEV

:PROD
echo Starting DeerFlow in [PRODUCTION] mode...
echo Starting DeerFlow in [PRODUCTION] mode... >> %LOGFILE%

REM 使用非阻塞方式启动后端服务 - 使用统一前缀的日志文件
cd /d "%PROJECT_ROOT%"
start "DeerFlow Backend" cmd /c "uv run server.py 2>&1 | tee %LOGFILE%-%LOGPREFIX%-backend-prod.log"

REM 等待后端服务启动
echo Waiting for backend service to start...
echo Waiting for backend service to start... >> %LOGFILE%
timeout /t 5 /nobreak > nul

REM 先构建前端项目
cd /d "%PROJECT_ROOT%web"
echo Building frontend...
echo Building frontend... >> %LOGFILE%
call pnpm build > %LOGFILE%-%LOGPREFIX%-frontend-build.log 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Frontend build failed with error code %ERRORLEVEL%
    echo Frontend build failed with error code %ERRORLEVEL% >> %LOGFILE%
    type %LOGFILE%-%LOGPREFIX%-frontend-build.log >> %LOGFILE%
    type %LOGFILE%-%LOGPREFIX%-frontend-build.log
    goto END
)

echo Frontend built successfully
echo Frontend built successfully >> %LOGFILE%

REM 同时启动前端服务 - 使用统一前缀的日志文件
cd /d "%PROJECT_ROOT%web"
start "DeerFlow Frontend" cmd /c "pnpm start 2>&1 | tee %LOGFILE%-%LOGPREFIX%-frontend-prod.log"

REM 回到项目根目录
cd /d "%PROJECT_ROOT%"

REM 等待用户关闭
echo Production services started. Check logs in %LOGFILE% and separate log files.
echo Production services started. Check logs in %LOGFILE% and separate log files. >> %LOGFILE%
echo Press any key to stop all services...
pause > nul

REM 关闭服务
echo Shutting down services...
echo Shutting down services... >> %LOGFILE%
taskkill /f /fi "WINDOWTITLE eq DeerFlow*" > nul 2>&1

REM 将单独的日志文件内容合并到主日志
type %LOGFILE%-%LOGPREFIX%-backend-prod.log >> %LOGFILE%
type %LOGFILE%-%LOGPREFIX%-frontend-prod.log >> %LOGFILE%
GOTO END

:DEV
echo Starting DeerFlow in [DEVELOPMENT] mode...
echo Starting DeerFlow in [DEVELOPMENT] mode... >> %LOGFILE%

REM 检查 web 目录的 node_modules 是否存在
IF NOT EXIST "%PROJECT_ROOT%web\node_modules" (
    echo Web 依赖未安装，正在安装...
    echo Web 依赖未安装，正在安装... >> %LOGFILE%
    cd "%PROJECT_ROOT%web"
    call pnpm install >> %LOGFILE% 2>&1
    cd "%PROJECT_ROOT%"
)

REM 创建包含完整路径的临时批处理文件用于启动后端服务
echo @echo off > "%PROJECT_ROOT%run_server.bat"
echo cd /d "%PROJECT_ROOT%" >> "%PROJECT_ROOT%run_server.bat"
echo uv run server.py --reload ^> "%LOGFILE%.server.log" 2^>^&1 >> "%PROJECT_ROOT%run_server.bat"
echo type "%LOGFILE%.server.log" >> "%PROJECT_ROOT%run_server.bat"
echo type "%LOGFILE%.server.log" ^>^> "%LOGFILE%" >> "%PROJECT_ROOT%run_server.bat"

REM 创建包含完整路径的临时批处理文件用于启动前端服务
echo @echo off > "%PROJECT_ROOT%run_web.bat"
echo cd /d "%PROJECT_ROOT%web" >> "%PROJECT_ROOT%run_web.bat"
echo call pnpm dev ^> "%LOGFILE%.web.log" 2^>^&1 >> "%PROJECT_ROOT%run_web.bat"
echo type "%LOGFILE%.web.log" >> "%PROJECT_ROOT%run_web.bat"
echo type "%LOGFILE%.web.log" ^>^> "%LOGFILE%" >> "%PROJECT_ROOT%run_web.bat"

REM 启动服务
start "DeerFlow Backend" cmd /c "%PROJECT_ROOT%run_server.bat"
start "DeerFlow Frontend" cmd /c "%PROJECT_ROOT%run_web.bat"

REM 等待用户关闭
echo Services started. Check logs in %LOGFILE%
echo Services started. Check logs in %LOGFILE% >> %LOGFILE%
echo Press any key to stop all services...
pause > nul

REM 关闭服务并清理
echo Shutting down services...
echo Shutting down services... >> %LOGFILE%
taskkill /f /fi "WINDOWTITLE eq DeerFlow Backend*" > nul 2>&1
taskkill /f /fi "WINDOWTITLE eq DeerFlow Frontend*" > nul 2>&1
del "%PROJECT_ROOT%\run_server.bat" "%PROJECT_ROOT%\run_web.bat" > nul 2>&1

:END
ENDLOCAL