---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '72501c90-a12d-4c43-9f1e-98c86c88ab70'
  PropagateID: '72501c90-a12d-4c43-9f1e-98c86c88ab70'
  ReservedCode1: '2855525f-5183-4a77-8ef4-95c3b03eae3d'
  ReservedCode2: '2855525f-5183-4a77-8ef4-95c3b03eae3d'
---

# Docker 开发环境约束

> 开发阶段使用 volume mount 热更新，生产部署使用 bake 进镜像。

---

## 文件结构

```text
compose.yaml              ← 生产配置（代码 bake 进镜像）
compose.override.yml       ← 开发覆盖（volume mount + 热更新）
```

Docker Compose 会自动合并 `compose.override.yml`，开发时无需额外参数。

## 开发环境（compose.override.yml）

web 服务的开发覆盖配置：

```yaml
services:
  web:
    volumes:
      - ./app:/app/app
      - ./public:/app/public
    environment:
      - NEXT_WATCH=1
    command: npm run dev
```

- 前端源码目录 bind mount 到容器内
- 改代码后 Next.js 热更新直接生效，无需重新 build 镜像
- 从 3 分钟构建 → 0 等待

## 生产环境（compose.yaml）

- 不使用 volume mount，代码 bake 进镜像
- 镜像自包含，不依赖宿主机目录结构
- 启动更快，可复现、可回滚

## 约束规则

1. **`compose.override.yml` 不提交到生产部署**。在 `.gitignore` 或 CI 中排除。
2. **切换到生产部署时**：`docker compose --profile production up -d`，明确跳过 override。
3. **新增盘型代码文件后**：验证开发环境热更新生效（改一行 → 刷新页面可见），再确认生产构建无报错。

## 检查清单

每次代码变更后：

- [ ] 开发环境下修改前端代码后刷新页面是否直接生效
- [ ] `docker compose build web` 生产构建是否通过
- [ ] 新增的 CSS 文件是否在 Next.js 的 import 链中（否则热更新不生效）

> AI生成