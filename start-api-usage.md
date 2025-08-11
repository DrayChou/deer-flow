# DeerFlow API 启动脚本使用说明

## 文件说明

- `start-api.bat` - Windows 批处理启动文件（主要入口）
- `start-api.ps1` - PowerShell 核心启动脚本
- `start-api-usage.md` - 使用说明（本文件）

## 使用方法

### 1. 双击运行
直接双击 `start-api.bat` 文件即可启动 API 服务器。

### 2. 命令行运行
```cmd
# 在项目根目录下运行
start-api.bat
```

## 脚本功能

### 编码处理
- 自动将 PowerShell 脚本转换为 UTF-8 with BOM 编码
- 设置控制台编码为 UTF-8，确保中文正确显示
- 防止中文乱码导致的启动失败

### 环境检查
- ✅ 检查是否在 DeerFlow 项目根目录
- ✅ 检查必要配置文件（.env, conf.yaml）
- ✅ 检查 UV 包管理器是否安装
- ✅ 验证 Python 环境和依赖

### 环境变量加载
- 自动读取 `.env` 文件中的所有环境变量
- 支持带引号的值（单引号和双引号）
- 忽略注释行和空行
- 显示加载的变量数量

### API 服务器启动
- 使用 `uv run uvicorn` 启动 FastAPI 服务器
- 监听地址: `http://localhost:8701`
- 支持热重载（--reload）
- 提供 API 文档访问地址

## 预期输出示例

```
🦌 DeerFlow API 启动器
=========================

📝 检测 PowerShell 脚本编码...
✅ PowerShell 脚本编码已转换为 UTF-8 with BOM

🚀 启动 PowerShell 脚本...

🦌 DeerFlow API 启动脚本
=========================
✅ 配置文件检查完成
✅ UV 版本: uv 0.x.x
📝 加载 .env 环境变量...
   设置: TAVILY_API_KEY
   设置: SEARCH_API
   ...
✅ 加载了 X 个环境变量
📦 检查项目依赖...
✅ Python 环境: 3.12.x
🚀 启动 DeerFlow API 服务器...
   服务器地址: http://localhost:8701
   API 文档: http://localhost:8701/docs
   按 Ctrl+C 停止服务器

INFO:     Uvicorn running on http://0.0.0.0:8701 (Press CTRL+C to quit)
INFO:     Started reloader process [xxxx] using StatReload
INFO:     Started server process [xxxx]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

## 常见问题解决

### 1. 错误: 请在 DeerFlow 项目根目录下运行
**解决方法**: 确保在包含 `pyproject.toml` 和 `main.py` 的目录下运行脚本

### 2. 错误: .env 文件不存在
**解决方法**: 
```bash
cp .env.example .env
# 然后编辑 .env 文件，添加必要的 API 密钥
```

### 3. 错误: conf.yaml 文件不存在
**解决方法**:
```bash
cp conf.yaml.example conf.yaml
# 然后编辑 conf.yaml 文件，配置 LLM 模型
```

### 4. 错误: UV 未安装
**解决方法**: 安装 UV 包管理器
```bash
# Windows
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 5. PowerShell 执行策略错误
脚本使用 `-ExecutionPolicy Bypass` 参数，通常不会遇到此问题。如果遇到，可以临时设置执行策略：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 停止服务器

在服务器运行时，按 `Ctrl+C` 即可停止服务器。

## 访问 API

服务器启动后，可以通过以下地址访问：

- **API 服务**: http://localhost:8701
- **API 文档**: http://localhost:8701/docs
- **OpenAPI 规范**: http://localhost:8701/openapi.json

## 日志和调试

脚本会显示详细的启动过程，包括：
- 配置文件检查结果
- 环境变量加载情况  
- 依赖检查状态
- 服务器启动日志

如果遇到问题，请查看控制台输出的错误信息进行排查。