---
name: docker-generator
description: "根据项目类型和技术栈自动生成 Dockerfile + docker-compose.yml + 数据库初始化脚本，确保 docker compose up 一键启动"
---

# Docker Generator — 容器化交付自动生成

## 概述

本 Skill 负责为后端/全栈项目自动生成符合交付规范的 Docker 配置文件。
**纯前端项目、移动端项目不调用本 Skill**。

## 触发条件

当 `docs/designs/_meta.md` 中 `project_type` 为以下任一值时触发：
- `fullstack` / `full_stack`
- `pure_backend`

## 执行步骤

### Step 1: 读取项目信息

从以下文件获取技术栈信息：
- `docs/designs/_meta.md` → 项目类型
- `docs/designs/requirement-analysis.md` → 技术栈、数据库
- `metadata.draft.json` → 结构化技术信息

### Step 2: 生成 Dockerfile

根据后端技术栈选择基础镜像模板：

#### Python 项目
```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE {port}

CMD ["python", "app.py"]
```

#### Node.js 项目
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE {port}

CMD ["node", "src/index.js"]
```

#### Java 项目
```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE {port}
CMD ["java", "-jar", "app.jar"]
```

**关键约束**：
- ✅ 使用公网可访问的基础镜像
- ✅ 所有依赖在 Dockerfile 内安装
- ✅ 不引用本地绝对路径
- ✅ 不需要交互式输入
- ✅ 使用 `.dockerignore` 排除 `node_modules/`, `.venv/`, `.git/` 等

### Step 3: 生成 docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "{host_port}:{container_port}"
    environment:
      - DATABASE_URL={db_connection_string}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  # 仅在项目使用数据库时生成
  db:
    image: {db_image}
    ports:
      - "{db_host_port}:{db_container_port}"
    environment:
      {db_env_vars}
    volumes:
      - db_data:/var/lib/{db_data_path}
      - ./init-db:/docker-entrypoint-initdb.d
    healthcheck:
      test: {healthcheck_cmd}
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  db_data:
```

#### 全栈项目多容器编排模板（fullstack 专用）

当 `project_type` 为 `fullstack` 时，使用以下三服务模板：

```yaml
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "{frontend_port}:80"
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "{backend_port}:{backend_container_port}"
    environment:
      - DATABASE_URL={db_connection_string}
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{backend_container_port}/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  db:
    image: {db_image}
    ports:
      - "{db_host_port}:{db_container_port}"
    environment:
      {db_env_vars}
    volumes:
      - db_data:/var/lib/{db_data_path}
      - ./init-db:/docker-entrypoint-initdb.d
    healthcheck:
      test: {healthcheck_cmd}
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  db_data:
```

**前端 Dockerfile 模板**（Nginx 静态文件 serve）：

```dockerfile
# 构建阶段
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 生产阶段
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**前端 nginx.conf 模板**（API 反向代理）：

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # SPA 路由 fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理到后端容器
    location /api/ {
        proxy_pass http://backend:{backend_container_port}/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**全栈项目选择策略**：
- 如果前后端在同一目录（如 Next.js/Nuxt.js SSR 项目）→ 使用单服务 `app + db` 模板
- 如果前后端分离（前端 React/Vue + 后端 Express/FastAPI）→ 使用三服务 `frontend + backend + db` 模板
- 判断依据：项目根目录是否同时存在 `frontend/` 和 `backend/`（或 `client/` 和 `server/`）子目录

#### 数据库配置模板

| 数据库 | 镜像 | 端口 | 环境变量 | Healthcheck |
|:---|:---|:---|:---|:---|
| PostgreSQL | `postgres:14-alpine` | 5432 | `POSTGRES_DB/USER/PASSWORD` | `pg_isready -U user` |
| MySQL | `mysql:8.0` | 3306 | `MYSQL_ROOT_PASSWORD/DATABASE` | `mysqladmin ping -h localhost` |
| MongoDB | `mongo:6` | 27017 | `MONGO_INITDB_ROOT_USERNAME/PASSWORD` | `mongosh --eval 'db.runCommand("ping")'` |
| SQLite | 不需要 DB 服务 | - | - | - |

### Step 4: 生成数据库初始化脚本

创建 `init-db/` 目录：

- PostgreSQL/MySQL → `init-db/001-init.sql`（建表+种子数据）
- MongoDB → `init-db/init-mongo.js`
- SQLite → 应用启动时自动创建

**约束**：
- ✅ 不打包 `.db`/`.sqlite` 文件，只用初始化脚本
- ✅ 包含测试账号种子数据
- ✅ SQL 语句使用 `IF NOT EXISTS` 确保幂等

### Step 5: 生成 .dockerignore

```
node_modules/
.venv/
venv/
__pycache__/
*.pyc
.git/
.vscode/
.idea/
*.db
*.sqlite
*.sqlite3
.env.local
.tmp/
docs/designs/
docs/plans/
```

### Step 6: 验证检查清单

生成前逐条确认：
- [ ] Dockerfile 不包含本地绝对路径
- [ ] docker-compose.yml 中所有端口显式暴露
- [ ] 不依赖宿主机上的数据库/Redis（全部声明在 compose 中）
- [ ] 不需要手动创建 `.env` 文件（环境变量直接写在 compose 或有默认值）
- [ ] 不需要手动导入 SQL（通过 init 脚本自动注入）
- [ ] 构建过程零交互式输入
- [ ] 使用 healthcheck 确保依赖服务就绪后才启动应用

## 完成条件

以下文件全部生成：
- `Dockerfile`
- `docker-compose.yml`
- `.dockerignore`
- `init-db/` 目录（如使用数据库）

输出 `DOCKER_GENERATION_COMPLETE`。
