# LifeScale 生产部署指南（Nginx + HTTPS）

> 📅 创建：2026-06-22（阶段 6）
> 🎯 用途：把 LifeScale 后端通过 HTTPS + 域名对外提供服务
> 🧭 关联：《项目重构与规范化指南.md》阶段 6、`docs/08_开发与部署工作流.md`

---

## 0. 架构概览

```
                     ┌─────────────────────────────────────────┐
                     │           腾讯云服务器（Linux）            │
   客户端 ──────────►│  :80  ──┐                                │
  (桌面/移动)        │  :443 ──┼──► nginx 容器                   │
   HTTPS            │         │     │  反代                      │
                    │         │     ▼                            │
                    │         │   backend 容器 (:8080, 容器内网络) │
                    │         │     │                            │
                    │         │     ├──► postgres 容器 (:5432)   │
                    │         │     └──► redis 容器 (:6379)      │
                    └─────────┴─────────────────────────────────┘
```

**关键设计**：
- nginx 是 docker compose 的一个服务（配置在 `docker-compose.full.yml`）
- SSL 证书由**宝塔面板**申请（Let's Encrypt 免费证书），证书文件放在 `nginx/certs/`
- 80/443 端口由 nginx 容器占用，backend 的 8080 仅绑定 127.0.0.1（不对外）
- 客户端 → nginx:443 → backend:8080（容器内网络，不走宿主机端口）

---

## 1. 前置条件清单

部署前必须确认以下都就绪：

### 1.1 域名
- [ ] 已购买域名（如 `lifescale.example.com`）
- [ ] DNS A 记录已添加：`lifescale.example.com` → 服务器公网 IP
- [ ] DNS 已生效：`nslookup lifescale.example.com` 返回服务器 IP（TTL 通常 10 分钟-1 小时）

### 1.2 服务器
- [ ] 腾讯云服务器已开通，能 SSH 登录
- [ ] **安全组放行 80 和 443 端口**（腾讯云控制台 → 安全组 → 入站规则）
- [ ] 服务器已安装 Docker + Docker Compose（`docker --version` / `docker compose version` 能输出版本）
- [ ] 服务器已安装 Git（`git --version`）

### 1.3 宝塔面板（用于申请 SSL 证书）
- [ ] 已安装宝塔面板（国际版或国内版均可）
- [ ] 宝塔能正常访问（默认 8888 端口，或你改过的端口）
- [ ] ⚠️ **不要**用宝塔自带的 nginx 接管 80/443（会和 docker nginx 冲突）。宝塔只用来申请 SSL 证书。

> 💡 **如果不想装宝塔**：可用 certbot 命令行申请（见本文档 §6 备选方案），或购买商业 SSL 证书后手动上传。

---

## 2. 首次部署 SOP

### 步骤 1：服务器拉取代码

```bash
ssh root@你的服务器IP
cd /opt    # 或你想放的目录
git clone https://gitee.com/XiaoZhi-paperfly/life-scale.git LifeScale
cd LifeScale/docker
```

### 步骤 2：在服务器创建 `.env`（生产真实密钥）

```bash
cp .env.production.example .env
vim .env    # 填入强随机真实值
```

**密钥生成**（在服务器上执行，不要用本地的）：
```bash
openssl rand -base64 48    # JWT secret，填到 LIFESCALE_JWT_SECRET
openssl rand -base64 24    # PG 密码，填到 POSTGRES_PASSWORD
openssl rand -base64 24    # Redis 密码，填到 REDIS_PASSWORD
```

填好后核验 `.env` 被忽略：
```bash
cd /opt/LifeScale
git check-ignore docker/.env    # 应输出 docker/.env
```

> ⚠️ **重要陷阱**（见《项目重构与规范化指南.md》§3.5.1）：docker compose 在 code/docker/ 下执行时，会向上查找 .env 找到项目根的 .env（如果存在），可能覆盖 docker/.env。**服务器上项目根不要放 .env**，只在 `code/docker/.env` 放。或者用下面的 source 法：
> ```bash
> cd /opt/LifeScale/docker
> export $(grep -v '^#' .env | grep -v '^$' | grep -E "^[A-Z_]+=" | xargs)
> docker compose -f docker-compose.full.yml up -d --build
> ```

### 步骤 3：申请 SSL 证书（宝塔面板）

#### 3.1 宝塔添加站点（仅用于申请证书，不真正建站）
1. 登录宝塔面板 → 网站 → 添加站点
2. 域名填 `lifescale.example.com`（你的真实域名）
3. 根目录随便（如 `/www/wwwroot/lifescale`）
4. **不要**选"反向代理"（我们用 docker nginx 反代）
5. PHP 版本选"纯静态"

#### 3.2 申请 Let's Encrypt 证书
1. 站点列表 → 点 `lifescale.example.com` → SSL
2. 选 "Let's Encrypt"
3. 勾选你的域名 → 申请
4. 申请成功后，证书文件位置：
   ```
   /www/server/panel/vhost/cert/lifescale.example.com/fullchain.pem
   /www/server/panel/vhost/cert/lifescale.example.com/privkey.pem
   ```

#### 3.3 复制证书到 nginx 挂载目录
```bash
# 在服务器上执行
mkdir -p /opt/LifeScale/docker/nginx/certs
cp /www/server/panel/vhost/cert/lifescale.example.com/fullchain.pem \
   /opt/LifeScale/docker/nginx/certs/fullchain.pem
cp /www/server/panel/vhost/cert/lifescale.example.com/privkey.pem \
   /opt/LifeScale/docker/nginx/certs/privkey.pem
chmod 644 /opt/LifeScale/docker/nginx/certs/*.pem
```

> ⚠️ **重要**：宝塔申请证书后，**关闭宝塔站点的"强制 HTTPS"和反向代理**，否则宝塔会占用 80/443 端口和 docker nginx 冲突。宝塔只负责申请+存储证书，不负责转发。

### 步骤 4：修改 nginx 配置里的域名

```bash
cd /opt/LifeScale/docker/nginx/conf.d
sed -i 's/YOUR_DOMAIN.com/lifescale.example.com/g' lifescale.conf
# 核验替换
grep server_name lifescale.conf
```

### 步骤 5：启动全栈

```bash
cd /opt/LifeScale/docker
# 用 source 法启动（避免 .env 陷阱）
export $(grep -v '^#' .env | grep -v '^$' | grep -E "^[A-Z_]+=" | xargs)
docker compose -f docker-compose.full.yml up -d --build
```

首次构建约 2-5 分钟（已配阿里云 Maven 镜像加速 + Docker Hub 镜像加速）。耐心等待。

> ⚠️ 如构建卡在 Maven 依赖下载或镜像拉取，参考 `DEPLOY-TEMP.md` §1.4（Docker Hub 加速）和 §6.6（Maven 依赖加速）排查。

### 步骤 6：验证

```bash
# 6.1 容器状态
docker compose -f docker-compose.full.yml ps
# 应看到 4 个容器都 healthy：postgres / redis / backend / nginx

# 6.2 HTTP → HTTPS 跳转
curl -I http://lifescale.example.com/api/health
# 应返回 301，Location: https://...

# 6.3 HTTPS 健康检查
curl https://lifescale.example.com/api/health
# 应返回 {"status":"UP",...}

# 6.4 SSL 证书有效
curl -vI https://lifescale.example.com 2>&1 | grep -E "subject|issuer|expire"
# 或浏览器访问，确认锁图标无警告

# 6.5 限流生效（连续打鉴权接口）
for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" https://lifescale.example.com/api/auth/login -X POST -H "Content-Type: application/json" -d '{}'; done
# 前 10 个返回 400/401，超过限流的返回 503
```

### 步骤 7：客户端配置更新

桌面端 `code/desktop/.env`：
```
VITE_API_BASE_URL=https://lifescale.example.com/api
```

移动端运行参数：
```bash
flutter run --dart-define=LIFESCALE_API_BASE_URL=https://lifescale.example.com/api --dart-define=LIFESCALE_USE_MOCK_API=false
```

或打包时：
```bash
flutter build apk --release \
  --dart-define=LIFESCALE_API_BASE_URL=https://lifescale.example.com/api \
  --dart-define=LIFESCALE_USE_MOCK_API=false
```

---

## 3. 本地验证（环境②，无 SSL 证书）

在本地 Docker 验证 nginx 反代链路（无需真实域名和证书）：

```bash
cd E:\AINewProject\LifeScale\code\docker

# 1. 切换到本地 HTTP 配置
cd nginx\conf.d
move lifescale.conf lifescale.conf.disabled
move lifescale.local.conf.disabled lifescale.local.conf
cd ..\..

# 2. 启动（用 source 法，见 §3.5.1 陷阱说明）
export $(grep -v '^#' .env | grep -v '^$' | grep -E "^[A-Z_]+=" | xargs)
docker compose -f docker-compose.full.yml up -d --build

# 3. 验证：走 nginx:80 → backend:8080
curl http://localhost/api/health
# 应返回 {"status":"UP",...}

# 4. 验证完恢复生产配置
cd nginx\conf.d
move lifescale.local.conf lifescale.local.conf.disabled
move lifescale.conf.disabled lifescale.conf
```

---

## 4. 日常迭代部署

代码更新后重新部署：

```bash
ssh root@你的服务器IP
cd /opt/LifeScale
git pull origin main
cd code/docker

# 重新构建+启动（数据卷保留，数据不丢）
export $(grep -v '^#' .env | grep -v '^$' | grep -E "^[A-Z_]+=" | xargs)
docker compose -f docker-compose.full.yml up -d --build

# 核验
curl https://lifescale.example.com/api/health
```

---

## 5. SSL 证书续期

Let's Encrypt 证书有效期 90 天，宝塔默认会自动续期。但续期后**证书文件位置不变**，需要同步到 nginx 挂载目录。

### 5.1 设置自动同步（推荐）

在服务器上创建 cron 任务：

```bash
crontab -e
```

添加（每天凌晨 3 点检查，证书更新了就同步）：
```cron
0 3 * * * cp /www/server/panel/vhost/cert/lifescale.example.com/fullchain.pem /opt/LifeScale/docker/nginx/certs/fullchain.pem && cp /www/server/panel/vhost/cert/lifescale.example.com/privkey.pem /opt/LifeScale/docker/nginx/certs/privkey.pem && docker exec lifescale-nginx nginx -s reload 2>&1 | logger -t lifescale-cert-sync
```

### 5.2 手动续期（备用）

```bash
# 宝塔续期：宝塔面板 → 网站 → SSL → 续签
# 或 certbot 命令行：certbot renew

# 续期后同步到 nginx
cp /www/server/panel/vhost/cert/lifescale.example.com/*.pem /opt/LifeScale/docker/nginx/certs/
docker exec lifescale-nginx nginx -s reload
```

---

## 6. 备选方案：certbot（不用宝塔）

如果不想装宝塔，用 certbot 命令行申请：

```bash
# 安装 certbot
apt update && apt install -y certbot

# 先临时启动 nginx HTTP only（用 lifescale.local.conf）
cd /opt/LifeScale/docker/nginx/conf.d
mv lifescale.conf lifescale.conf.disabled
mv lifescale.local.conf.disabled lifescale.local.conf
cd /opt/LifeScale/docker
docker compose -f docker-compose.full.yml up -d

# 申请证书（webroot 模式，nginx 的 :80 路径 /.well-known/acme-challenge/ 已配好）
certbot certonly --webroot -w /var/www/certbot -d lifescale.example.com

# 证书在 /etc/letsencrypt/live/lifescale.example.com/
cp /etc/letsencrypt/live/lifescale.example.com/fullchain.pem nginx/certs/
cp /etc/letsencrypt/live/lifescale.example.com/privkey.pem nginx/certs/

# 恢复生产配置
cd nginx/conf.d
mv lifescale.local.conf lifescale.local.conf.disabled
mv lifescale.conf.disabled lifescale.conf
cd ..
docker compose -f docker-compose.full.yml up -d --build
```

certbot 自动续期：`certbot renew` 已自动加到 cron（`/etc/cron.d/certbot`），续期后需同步到 nginx/certs/ 并 reload。

---

## 7. 故障排查

### 7.1 nginx 容器起不来
```bash
docker logs lifescale-nginx
```
常见原因：
- `cannot load certificate "/etc/nginx/certs/fullchain.pem"`：证书文件没放或路径错。确认 `nginx/certs/fullchain.pem` 和 `privkey.pem` 存在。
- `host not found in upstream "backend"`：backend 容器没起来或不在同网络。`docker compose ps` 确认 backend healthy。

### 7.2 502 Bad Gateway
- backend 容器挂了：`docker logs lifescale-backend`
- backend 还在启动中：等 30-60 秒（Flyway 迁移 + JVM 预热）

### 7.3 域名打不开
- DNS 未生效：`nslookup lifescale.example.com`
- 安全组没放行 80/443：腾讯云控制台检查
- 服务器防火墙：`ufw status` 或 `firewall-cmd --list-all`

### 7.4 SSL 证书无效（浏览器警告）
- 证书过期：`openssl x509 -in nginx/certs/fullchain.pem -noout -dates`
- 域名不匹配：确认 nginx.conf 的 server_name 和证书域名一致
- 证书链不全：用宝塔或 certbot 申请的 fullchain.pem 通常已含中间证书

### 7.5 端口被占用
```bash
# 看 80/443 被谁占
netstat -tlnp | grep -E ':80|:443'
# 若被宝塔 nginx 占用：
#   宝塔面板 → 软件商店 → 已安装 → Nginx → 停止
#   或 systemctl stop nginx
```

### 7.6 docker compose 读错 .env
见《项目重构与规范化指南.md》§3.5.1 陷阱 A。用 `export $(grep ...)` 法启动。

---

## 8. 安全检查清单

部署完成后逐项确认：
- [ ] HTTPS 可访问，证书有效（浏览器无警告）
- [ ] HTTP 自动跳转 HTTPS
- [ ] `/api/health` 返回 UP
- [ ] Swagger UI 生产是否需要（如不需，注释掉 nginx.conf 的 swagger location）
- [ ] 8080 端口不对外（`curl http://服务器IP:8080` 应连接失败）
- [ ] 管理员密码已改（非弱默认）
- [ ] SSL 证书自动续期已配置

---

## 附：文件清单

```
code/docker/
  docker-compose.full.yml          # 含 nginx 服务（修改后）
  .env                             # 生产密钥（不入库，服务器创建）
  .env.production.example          # 模板（入库）
  nginx/
    conf.d/
      lifescale.conf               # 生产 HTTPS 配置（入库，模板，需替换域名）
      lifescale.local.conf.disabled # 本地 HTTP 验证（入库，默认不生效）
    certs/                         # SSL 证书（不入库，.gitignore 忽略）
      fullchain.pem                # 宝塔申请后复制过来
      privkey.pem
    logs/                          # nginx 日志（不入库，.gitignore 忽略）
    DEPLOY.md                      # 本文档
```
