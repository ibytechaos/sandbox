# Docker Image Reverse Engineering

这个项目包含了对 `ghcr.io/agent-infra/sandbox` 镜像的逆向工程结果。

## 项目结构

```
.
├── Dockerfile                          # 逆向工程的 Dockerfile
├── README.md                          # 项目说明文档
├── config/                           # 从原镜像提取的配置文件
│   ├── opt/                          # 应用程序配置
│   │   ├── gem/                      # GEM 相关配置
│   │   ├── gem-server/               # GEM 服务器代码
│   │   ├── novnc/                    # NoVNC 配置
│   │   └── aio/                      # AIO 配置
│   └── ...
└── scripts/                          # 自动化脚本
    ├── reverse_docker_image.sh       # 逆向工程自动化脚本
    └── build_image.sh                # 镜像构建脚本
```

## 逆向工程过程

### 1. 镜像分析

通过以下命令分析了原始镜像：

```bash
# 拉取镜像
docker pull ghcr.io/agent-infra/sandbox

# 分析镜像信息
docker inspect ghcr.io/agent-infra/sandbox

# 查看构建历史
docker history ghcr.io/agent-infra/sandbox
```

### 2. 文件提取

启动容器并提取重要配置文件：

```bash
# 启动容器保持运行
docker run -d --name sandbox-reverse ghcr.io/agent-infra/sandbox tail -f /dev/null

# 提取配置文件
docker cp sandbox-reverse:/opt/gem/ config/
docker cp sandbox-reverse:/opt/gem-server/ config/
docker cp sandbox-reverse:/opt/novnc/ config/
docker cp sandbox-reverse:/opt/aio/ config/
```

### 3. Dockerfile 重构

基于分析结果重构了 Dockerfile，包含：

- **基础镜像**: Ubuntu 22.04
- **环境变量**: 浏览器配置、服务端口、语言设置等
- **系统依赖**: Python、Node.js、Nginx、Supervisor 等
- **应用配置**: 从提取的文件复制配置
- **服务设置**: 健康检查、端口暴露等

### 4. 关键组件

镜像包含以下主要组件：

- **浏览器服务**: Chromium/Chrome 浏览器控制
- **Jupyter Lab**: Python 开发环境
- **Code Server**: VS Code 服务器
- **NoVNC**: 远程桌面访问
- **Nginx**: 反向代理服务器
- **Supervisor**: 进程管理
- **MCP 服务**: 多协议通信服务

## 使用方法

### 自动化逆向工程

使用提供的脚本自动化整个逆向工程过程：

```bash
# 运行逆向工程脚本
./scripts/reverse_docker_image.sh [镜像名称]

# 默认会逆向 ghcr.io/agent-infra/sandbox
./scripts/reverse_docker_image.sh
```

### 手动构建镜像

```bash
# 构建逆向工程的镜像
./scripts/build_image.sh

# 或者手动构建
docker build -t sandbox-reversed .
```

### 运行镜像

```bash
# 交互式运行
docker run -it sandbox-reversed

# 后台运行并映射端口
docker run -d -p 8080:8080 --name sandbox sandbox-reversed

# 运行并保持容器活跃
docker run -d --name sandbox sandbox-reversed tail -f /dev/null
```

## 配置文件说明

### 主要配置目录

- **`/opt/gem/`**: 核心应用配置
  - `browser-ctl.sh`: 浏览器控制脚本
  - `mcp-ctl.sh`: MCP 服务控制脚本
  - `nginx/`: Nginx 配置文件
  - `supervisord/`: Supervisor 配置文件

- **`/opt/gem-server/`**: GEM 服务器源代码
  - Python FastAPI 应用
  - 提供 REST API 接口

- **`/opt/novnc/`**: NoVNC 远程桌面配置

### 环境变量

```bash
# 浏览器配置
BROWSER_REMOTE_DEBUGGING_PORT=9222
PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/browser

# 服务端口
SANDBOX_SRV_PORT=8091
JUPYTER_LAB_PORT=8888
CODE_SERVER_PORT=8200

# 系统配置
LANG=en_US.UTF-8
TZ=Asia/Singapore
```

## 注意事项

1. **依赖关系**: 确保所有系统依赖都已正确安装
2. **权限设置**: 某些脚本需要执行权限
3. **端口冲突**: 注意端口映射避免冲突
4. **资源需求**: 镜像较大，需要足够的磁盘空间

## 故障排除

### 常见问题

1. **构建失败**: 检查 Docker 是否正常运行
2. **文件缺失**: 确保 `config` 目录存在
3. **权限错误**: 检查脚本执行权限

### 调试方法

```bash
# 查看容器日志
docker logs sandbox

# 进入容器调试
docker exec -it sandbox /bin/bash

# 检查服务状态
docker exec sandbox supervisorctl status
```

## 许可证

本项目仅用于学习和研究目的。请遵守原始镜像的许可证条款。