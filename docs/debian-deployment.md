# 在 Debian 12 部署 BubbleShark Nexus

本指南部署当前 Nexus 首页、安装中心和 FAQ。项目通过 `pnpm generate` 生成静态站点，Debian 服务器由 Nginx 提供访问。服务器无需安装 Node.js、pnpm 或运行 `pnpm dev`。Panel 与 DST 实例有独立的安装流程。

## 1. 确认服务器环境

使用 SSH 连接，或打开服务器控制台的终端。以下服务器命令以 root 身份执行；普通用户可以先执行 `sudo -i`。

```sh
whoami
cat /etc/os-release
ss -lntp | grep -E ':(80|443)[[:space:]]' || true
```

确认系统是 Debian 12。若 80 / 443 已由网站管理工具的 Nginx、OpenResty 或其他服务占用，复用该工具的静态网站功能，将下面生成的静态文件放到该站点根目录，并采用 `deploy/nginx-nexus.conf` 中的路由规则。下文安装独立 Nginx 的步骤适用于这些端口空闲的机器。

在云平台安全组 / 防火墙开放 TCP 80；配置 HTTPS 时也开放 TCP 443。SSH 使用服务器实际设置的端口。若已经启用了本机防火墙，还需在其中放行网站端口；不要为了部署网站关闭现有防火墙。

## 2. 在本地 Windows 构建

当前已验证的浅粉主题上传包位于 `.artifacts/nexus-site.tar.gz`。首次通过公网 IP 验证时可以直接使用此包，不必重新构建。压缩包仅含 `.output/public` 中的公开网站文件，没有项目源码、node_modules 或 .env。

以后修改网站，或已经有正式域名时，在本地 PowerShell 执行：

```powershell
Set-Location D:\Code\bubble-shark-nexus
pnpm install --frozen-lockfile

# 已有正式域名时设置；请替换为你的真实域名，无结尾斜杠。
# 暂时只用 IP 预览时省略这一行，并保持 .env 中该值为空。
$env:NUXT_PUBLIC_SITE_URL = "https://nexus.example.com"

pnpm generate
if ($LASTEXITCODE -ne 0) { throw "静态构建失败，请先处理上方错误" }
New-Item -ItemType Directory -Force .artifacts | Out-Null
tar -czf .artifacts/nexus-site.tar.gz -C .output/public .
if ($LASTEXITCODE -ne 0) { throw "打包失败" }
```

正式域名需要在构建时设置，才能生成正确的 canonical、OpenGraph URL、robots 和 sitemap。已生成的静态文件不会读取服务器上的环境变量。当前 IP 预览包没有配置正式域名，robots 禁止索引，sitemap 为空。

如果本地正运行 `pnpm preview`，先关闭该预览终端中的进程，再重新生成；Windows 上预览进程可能占用 `.output`，导致构建报 `EBUSY`。

## 3. 上传到服务器

在本地 Windows PowerShell 执行，替换 `服务器公网IP`。以下示例采用 root 和默认 SSH 端口 22；如果供应商配置了其他端口，在 scp 后加入 `-P 实际端口`。

```powershell
Set-Location D:\Code\bubble-shark-nexus
scp .artifacts/nexus-site.tar.gz deploy/nginx-nexus.conf root@服务器公网IP:/tmp/
```

也可以使用 SFTP 客户端或服务器管理工具的文件上传功能，将这两个文件上传到服务器的 `/tmp/`。

## 4. 在服务器安装并配置 Nginx

以下步骤用于首次部署，且服务器没有占用 80 端口的其他网站服务。命令在服务器 root 终端执行。

```sh
apt-get update
apt-get install -y nginx ca-certificates curl

install -d -m 755 /var/www/bubbleshark-nexus
tar -xzf /tmp/nexus-site.tar.gz -C /var/www/bubbleshark-nexus
find /var/www/bubbleshark-nexus -type d -exec chmod 755 {} +
find /var/www/bubbleshark-nexus -type f -exec chmod 644 {} +

cp /tmp/nginx-nexus.conf /etc/nginx/sites-available/bubbleshark-nexus
ln -sfn /etc/nginx/sites-available/bubbleshark-nexus /etc/nginx/sites-enabled/bubbleshark-nexus

# 只停用 Debian 自带的默认站点链接，原配置文件保留。
if [ -L /etc/nginx/sites-enabled/default ]; then
    unlink /etc/nginx/sites-enabled/default
fi

nginx -t && systemctl enable --now nginx && systemctl reload nginx
```

配置检查失败时，先根据 `nginx -t` 的输出修正配置再启动。网站根目录应直接包含 `index.html`、`install/`、`faq/`、`_nuxt/`、`__nuxt_content/`、`logo/` 等内容，不应再套一层 `public/`。

`try_files` 保证直接访问或刷新 `/install`、`/faq` 时读取已预渲染的页面；不存在的路径返回 HTTP 404 并显示项目错误页。缺失的 JS、WASM 和 FAQ 数据不会被替换成首页 HTML。

## 5. 验证访问

先在服务器执行：

```sh
curl -I http://127.0.0.1/
curl -I http://127.0.0.1/install/
curl -I http://127.0.0.1/faq/
curl -I http://127.0.0.1/__nuxt_content/faq/sql_dump.txt
curl -I http://127.0.0.1/this-page-does-not-exist
```

前四项应返回 200；最后一项应返回 404。然后在自己电脑的浏览器打开 `http://服务器公网IP/`，验证首页、安装中心、命令复制、FAQ 搜索，并直接刷新 `/install/` 和 `/faq/`。

服务器 curl 正常而外部无法访问时，检查云平台安全组、本机防火墙、公网 IP 与网络映射。看到 Nginx 默认欢迎页时，检查默认站点是否停用、配置中的 root 是否正确，并重新执行 `nginx -t` 和 reload。

如果网页能打开但命令复制失败，先按界面提示手动复制，绑定域名并启用 HTTPS 后再测。浏览器的剪贴板 API 在公网 HTTP 环境下可能不可用。

## 6. 绑定域名与 HTTPS

将域名（例如 `nexus.example.com`）的 A 记录指向服务器公网 IPv4。如果配置 AAAA，也要确保对应 IPv6 可以访问服务器。

将 `/etc/nginx/sites-available/bubbleshark-nexus` 中的 `server_name _;` 改成实际域名，例如：

```nginx
server_name nexus.example.com;
```

在服务器执行，替换示例域名：

```sh
nginx -t && systemctl reload nginx
apt-get install -y certbot python3-certbot-nginx
certbot --nginx -d nexus.example.com
certbot renew --dry-run
```

申请证书前，域名需要解析到这台服务器，外部应能访问 TCP 80 / 443。Certbot 会交互询问邮箱和服务条款；由服务器管理员填写和确认。

再在本地按第 2 步设置 `NUXT_PUBLIC_SITE_URL=https://实际域名`，重新构建、打包和上传，替换站点内容。这里需要重建，因为 canonical、robots 和 sitemap 是构建时生成的。

## 7. 后续更新

在本地重新构建并打包，上传新的 `.artifacts/nexus-site.tar.gz`。服务器可以直接解压到同一网站根目录；只更新静态文件时无需重启 Nginx。不要删除仍可能被用户旧页面引用的 `_nuxt` 文件；覆盖式更新会暂时保留旧资源。如果以后需要严格控制旧资源和回滚，再采用独立 release 目录切换。

若使用服务器管理工具的网站界面，请始终通过该工具维护其管理的站点配置，避免同时用独立服务覆盖它。

## 与 Panel 同机部署

Nexus 使用网站的 80 / 443 端口；Panel 默认使用 TCP 9527，DST 地上与洞穴使用其各自的 UDP 端口，不会因为共用一台机器而必然冲突。Panel 的部署与实例创建参考 [Docker 安装](../data/panel/docs/install-docker.md)，并仅对需要访问 Panel 的来源开放管理端口。开启洞穴时需按该文档放行游戏的 UDP 端口。

## 来源与验证范围

- [Nuxt 静态预渲染](https://nuxt.com/docs/4.x/getting-started/prerendering)
- [Nginx try_files 与 error_page](https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)
- [Debian 12 Nginx 包](https://packages.debian.org/bookworm/amd64/nginx)
- [Certbot Nginx 插件](https://eff-certbot.readthedocs.io/en/stable/using.html#nginx)

本地静态构建、页面功能与上传包内容已经核对；尚未连接到用户服务器，Nginx 配置需要在目标 Debian 12 上执行 `nginx -t` 并验收公网访问。
