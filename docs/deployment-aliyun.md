# Interstellar 阿里云独立部署

## 1. 固定约束

- 正式域名：`https://fate.xiaoguiwk.top`。
- Interstellar 使用独立的 `interstellar-web`、`interstellar-api` 容器、SQLite 数据目录和 `interstellar-internal` 网络。
- 公共 Caddy 只承担 80/443 TLS 与反向代理入口；流量直接进入 Interstellar 容器，不经过 Ledger 应用、Ledger 容器或 Ledger 的内部代理链。
- 浏览器统一使用同源 `/api/v1`，不会把内网端口或 API 密钥嵌入前端包。
- 生产账户 Cookie 必须启用 `Secure`、`HttpOnly` 与 `SameSite=Lax`。

## 2. 服务路径

```text
Internet
  -> fate.xiaoguiwk.top:443
  -> shared Caddy (TLS only)
      -> /api/v1/* -> interstellar-api:8018
      -> /*         -> interstellar-web:3000
```

服务器目录固定为：

```text
/opt/interstellar/
  compose.production.yaml
  .env                         # 仅服务器，0600
  data/accounts.sqlite3        # 账户、人物、最新本命盘
  source/                      # 当前发布源码
```

`data/` 必须纳入备份；源码和镜像可以从 Git 提交重建。

## 3. 发布顺序

1. 本地通过 `npm run test`，并使用无 `NEXT_PUBLIC_INTERSTELLAR_API_URL` 的同源生产构建。
2. 上传已提交源码到 `/opt/interstellar/source`。
3. 创建 `/opt/interstellar/data`，所有者设为容器账户 `10001:10001`，权限设为 `0700`。
4. 从 `infra/deploy/interstellar.env.example` 创建服务器专用 `.env`，权限设为 `0600`。
5. 执行 `docker compose -f infra/deploy/compose.production.yaml up -d --build`。
6. 将公共 Caddy 连接到 `interstellar-internal` 网络。
7. 将 `infra/deploy/Caddyfile.fate` 站点块追加到公共 Caddyfile，校验配置后 reload。
8. 检查 `/health/ready`、主页、注册、登录、游客计算和账户隔离。

## 4. AI 密钥

DeepSeek 密钥只允许写入服务器 `.env` 或后续秘密管理器。聊天记录、前端变量、Git、构建参数和日志均不得包含真实密钥。泄露或在聊天中发送过的密钥必须轮换后才能用于生产。

## 5. 数据与回滚

- 发布前备份 `/opt/interstellar/data` 与 `/opt/caddy/Caddyfile`。
- 每个人物只保留最新一次本命盘结果；重算使用 SQLite UPSERT 覆盖旧结果。
- 回滚应用时切回上一镜像标签；除非数据库结构明确兼容，不覆盖最新账户数据。
- Caddy 配置校验失败时不 reload，保留上一份可用配置。
