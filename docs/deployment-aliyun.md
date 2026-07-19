# Interstellar 阿里云 Docker 独立部署

## 1. 固定约束

- 正式域名：`https://fate.xiaoguiwk.top`；DNS A/AAAA记录必须先解析到目标服务器。
- Interstellar使用独立Compose项目`interstellar-production`、`interstellar-web`、`interstellar-api`、SQLite数据目录和`interstellar-internal`网络。
- 公共Caddy必须是独立边缘容器或服务，只承担80/443、TLS和反向代理；流量不得经过Ledger应用、Ledger容器或其内部代理链。
- 浏览器统一使用同源`/api/v1`，不会把内网端口或API密钥嵌入前端包。
- 生产账户Cookie必须启用`Secure`、`HttpOnly`与`SameSite=Lax`。
- 发布源码必须对应Git提交；真实`.env`、数据库、API Key和备份不得进入仓库或镜像。

## 2. 服务路径

```text
Internet
  -> fate.xiaoguiwk.top:443
  -> Docker Caddy（TLS only）
      -> /api/v1/* -> interstellar-api:8018
      -> /*         -> interstellar-web:3000
```

服务器目录固定为：

```text
/opt/interstellar/
  source/                      # 当前发布源码
  .env                         # 仅服务器，0600
  data/accounts.sqlite3        # 账户、对象、最新本命盘、后台数据
  backups/                     # 数据与配置备份，0700
```

`data/`必须纳入备份；源码和镜像可从Git提交重建。Caddy只需连接`interstellar-internal`网络，不需要公开Web/API容器端口。

## 3. 小内存运行档

当前全球Timezone Boundary Builder文件解压后约168 MB，原实现会在API启动时把全部GeoJSON和几何索引载入内存。生产Compose因此默认使用仓库内的空边界FeatureCollection，并使用GeoNames官方IANA时区提示作为降级候选：

- 地点搜索和经纬度仍来自本地GeoNames；
- 时区候选标记为`dataset_hint_only`，必须由用户确认；
- 不伪装为精确多边形匹配；
- API限制为1024 MB，Web限制为384 MB；
- 2 GiB服务器必须顺序构建镜像，不能并行构建。

4 GiB及以上主机需要精确边界时，可启用镜像内锁定的完整官方ZIP（或只读挂载同版本文件），并覆盖：

```text
INTERSTELLAR_TIMEZONE_BOUNDARIES_PATH=/opt/interstellar/vendor/timezone-boundary-builder/timezones-2026b.geojson.zip
INTERSTELLAR_TIMEZONE_BOUNDARIES_DATASET_VERSION=2026b-full
```

启用完整边界前必须在目标机测量API启动峰值内存；不得只因文件压缩后约48 MB就假设内存足够。

## 4. 首次发布

1. 确认域名解析、服务器80/443入站规则和Docker Engine/Compose可用。
2. 本地执行`npm run test`、`npm run build`、后台测试和文档校验；生产构建不得设置`NEXT_PUBLIC_INTERSTELLAR_API_URL`。
3. 将已提交源码同步到`/opt/interstellar/source`，不要上传本地`node_modules`、`.env`和SQLite。
4. 创建数据与备份目录：容器数据目录所有者为`10001:10001`、权限`0700`，服务器`.env`权限`0600`。
5. 从`infra/deploy/interstellar.env.example`创建`/opt/interstellar/.env`，配置镜像标签、提交SHA、轮换后的DeepSeek密钥、`INTERSTELLAR_ADMIN_MASTER_KEY`以及首个超级管理员的邮箱和密码。主密钥和管理员密码都不得进入Git。
6. 在`/opt/interstellar/source`按顺序构建，避免小内存主机并行耗尽：

```sh
COMPOSE_PARALLEL_LIMIT=1 docker compose --env-file /opt/interstellar/.env -f infra/deploy/compose.production.yaml build api
COMPOSE_PARALLEL_LIMIT=1 docker compose --env-file /opt/interstellar/.env -f infra/deploy/compose.production.yaml build web
docker compose --env-file /opt/interstellar/.env -f infra/deploy/compose.production.yaml up -d --no-build
```

7. 将独立公共Caddy容器连接到`interstellar-internal`网络，把`infra/deploy/Caddyfile.fate`站点块加入其配置，先执行`caddy validate`再reload。
8. 等待HTTPS证书签发，检查Compose健康、容器内存、API readiness、主页和浏览器同源API。
9. 完成注册、登录、游客计算、账户隔离、对象库新增/编辑/删除/默认、推荐方案预检、工作台最新本命恢复和DeepSeek提交验收。对象库不得出现打开结果或重新分析按钮。
10. 验证普通用户`403`、管理员登录、用户停用/恢复、最后超级管理员保护、密钥掩码、提示词配置和审计日志。

如果服务器使用`docker-compose`而非`docker compose`，命令参数保持一致。发布脚本必须先探测可用命令，不能把插件缺失误判为Compose文件错误。

## 5. 发布前检查

```sh
docker-compose -f infra/deploy/compose.production.yaml config --quiet
docker-compose -f infra/deploy/compose.production.yaml ps
curl --fail --silent https://fate.xiaoguiwk.top/health/ready
curl --fail --silent --head https://fate.xiaoguiwk.top/
```

同时检查：

- `interstellar-web`和`interstellar-api`均为healthy；
- API常驻内存未接近1024 MB上限，Web未接近384 MB；
- Caddy证书、SNI和反向代理命中`fate.xiaoguiwk.top`；
- 浏览器Cookie包含`Secure`、`HttpOnly`和`SameSite=Lax`；
- 页面源代码、静态JS、容器inspect、日志和API响应不出现完整API Key；
- 普通用户与游客不能访问后台接口；
- Ledger停机或重启不会影响Interstellar入口。

## 6. AI与后台密钥

DeepSeek密钥只允许写入服务器`.env`、Docker Secret或后续后台加密密钥库。聊天记录、前端变量、Git、构建参数、行为事件和日志均不得包含真实密钥。聊天中发送过的密钥必须轮换后才能用于生产。

后台密钥管理上线后，部署环境必须提供独立的密钥加密主密钥；后台只显示提供方、模型、状态、最近测试和密钥末4位，完整密钥保存后永不回显。修改密钥写入管理员审计日志，但日志不得保存密钥值。

平台AI预分析提示词使用版本化后台配置，并可按提供方/模型覆盖。生产AI产物记录生效提示词版本和哈希；提示词正文属于受限运营配置，不进入普通用户接口、前端Bundle、行为事件和导出。服务端必须先注入代码内不可变安全边界，再注入平台提示词，管理员配置不能覆盖此顺序。

## 7. 备份、升级与回滚

- 发布和数据库迁移前，先对SQLite执行一致性备份，并备份公共Caddy配置；不要直接复制正在写入的数据库文件。
- 每个人物只保留最新一次本命结果；重算使用事务内UPSERT覆盖旧结果。
- 账户状态、管理员、审计、用量和提供方配置迁移必须在备份后执行，并验证旧账户可登录。
- 应用回滚使用上一Git提交/镜像标签；除非迁移文档明确支持，不用旧镜像覆盖新数据库结构。
- Caddy配置校验失败时不得reload，继续使用上一份可用配置。
- 回滚后重新验证健康、登录、账户隔离、对象最新结果、管理员授权和AI配置状态。

## 8. 当前限制

- 当前首发SQLite适合单实例；不能同时启动多个写API副本。
- 小内存档的时区边界是明确降级，用户必须确认IANA时区；需要精确多边形匹配时升级主机内存或后续改为磁盘/数据库空间索引。
- 后台角色、状态、用量、模型配置、加密密钥库和提示词已经进入首发实现；生产是否可用仍以管理员引导、权限测试、密钥加密主密钥和审计验收为准。
- 本部署不承诺企业级SLA、多区域、高可用数据库和零停机迁移。
