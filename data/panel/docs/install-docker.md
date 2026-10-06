# Docker 模式安装

面板与游戏都跑在容器里，由 Docker Compose 编排。适合小型游戏社区与托管商。

**环境要求**：Debian 12 或 Ubuntu 22.04 / 24.04（只支持 apt 系），root 或 sudo，至少 4 GiB 内存，根分区至少 4 GiB 空闲——离线镜像包约 227 MB，导入后本地镜像约 560 MB（包可删），另外要给游戏本体（数 GB）和存档备份留地方。

小内存机的缓存区由安装器自动配置：总内存低于 5 GiB 且当前没有缓存区时它会创建 swapfile 并写进 `/etc/fstab`（`--no-swap` 可关闭）。分片加载整套 Mod 时内存会短时冲高，没有缓存区会被内核在加载途中杀掉，表现为「实例显示运行中但大厅搜不到」。从旧版本升级上来的机器仍可手动执行 `sudo bsp setup-swap`。档位参考[内存档位](MEMORY.md)。

Windows 不是部署目标，只用于本机开发调试。

## 安装（海外机器）

一条命令装完，安装器自己装 Docker 与 Compose 插件，再拉取统一镜像并启动面板栈。想先确认环境再动手，可以加 `--check`：它只打印体检报告，不改动系统。

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.15.3/scripts/install.linux.sh" \
  | sudo bash -s -- --mode docker
```

GHCR 拉取慢或超时的话，把上面命令里的 `https://raw.githubusercontent.com` 换成 `https://gh-proxy.com/https://raw.githubusercontent.com`，其余不变。

## 安装（国内服务器）

国内的问题集中在镜像下载：安装器拉的是 GHCR 镜像，而它的镜像层域名 `pkg-containers.githubusercontent.com` 国内基本不可达，直接跑常卡在 `net/http: TLS handshake timeout`。

安装命令本身就是体检加安装：**不需要额外先跑一次体检**。安装器会先判断发行版、架构、内存、根分区余量、Docker 状态、GHCR 与 Steam CDN 可达性、面板端口占用，把这份报告打到屏幕上（同时写进安装状态文件），确认没有阻塞项才继续装。

```bash
tag=v0.15.3
# gh-proxy 加速；不可用时换成 https://ghfast.top/ 前缀。
# 用 curl -o 指定带版本号的文件名：wget 遇到同名文件是另存为 .1，容易继续跑上一次的旧脚本
curl -fL --retry 3 -o "install-${tag}.sh" \
  "https://gh-proxy.com/https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/${tag}/scripts/install.linux.sh"

# 自证版本：这一步必须输出 ...:-v0.15.3}}，对不上就停下排查。
# 这一行的默认 tag 决定安装器要装的镜像版本
grep '^BSP_RELEASE_TAG=' "install-${tag}.sh"

# 国内档位：发行版换国内镜像源，SteamCMD 重试次数翻倍
sudo BSP_PANEL_ENV_PRESET=small bash "install-${tag}.sh" --mode docker --network cn
```

**不需要手动下载或导入镜像包**：`--network cn` 下安装器默认走 Release 离线镜像包（走加速代理池、校验 `.sha256`、`docker load` 导入）；海外档默认从 GHCR 直拉，但会先实测**层数据**能不能拉——元数据可达不算数，测不通就自动改走离线包。

直拉时若连续 90 秒没有进度，安装器会主动放弃并中断，不再让你盯着 `Waiting`：

```
[WARN] docker pull 已连续 90s 没有进度，判定停滞并放弃本次尝试。
[WARN] 已中断停滞的拉取；本地已完成的层会保留，重试或改用离线包都不会从头开始。
```

想固定走某条路线时用 `BSP_IMAGE_SOURCE`：

```bash
# 固定用离线包（国内推荐，行为最可预期）
sudo BSP_IMAGE_SOURCE=offline bash "install-${tag}.sh" --mode docker --network cn

# 固定直拉（自建 registry 或确认 GHCR 层数据可用时）
sudo BSP_IMAGE_SOURCE=native bash "install-${tag}.sh" --mode docker
```

装完终端会打印面板地址、管理员账号与后续动作，结尾还会给出这次安装的耗时。

<details>
<summary>只想看这台机器能不能装，先不安装：加 --check</summary>

`--check` 打印的是同一份体检报告，区别只在「到此为止」：它不改动系统，不装依赖、不建目录、不写安装状态文件，也不会去拉镜像。适合在还没决定是否安装时先评估一台机器，或者把它当成巡检探针。

```bash
sudo bash "install-${tag}.sh" --check
```

体检有阻塞项（架构不支持、根分区不足、systemd 缺失、面板端口被占用）时它返回退出码 1，因此也能直接串进自动化脚本。确认环境合适后，去掉 `--check` 重跑同一条命令即可开始安装。

</details>

<details>
<summary>自动兜底失败时：手动下载并导入离线镜像包</summary>

安装器已经把能试的代理都试过才会退回这里。手动路径是它做过的同一套动作：

```bash
base="https://gh-proxy.com/https://github.com/PMAT77/bubble-shark-panel/releases/download/${tag}"
# 下载镜像包与校验文件（约 227 MB，以 Release 页面显示为准）
curl -fL --retry 3 -o "bubblesharkpanel-${tag}-docker-image.tar.gz"        "${base}/bubblesharkpanel-${tag}-docker-image.tar.gz"
curl -fL --retry 3 -o "bubblesharkpanel-${tag}-docker-image.tar.gz.sha256" "${base}/bubblesharkpanel-${tag}-docker-image.tar.gz.sha256"

# 校验完整性，末尾应输出 OK。.sha256 记录的是原始文件名，改过名要先改回
sha256sum -c "bubblesharkpanel-${tag}-docker-image.tar.gz.sha256"

# 导入镜像（约 560 MB）；-i 带进度条，不要用 gunzip 管道
docker load -i "bubblesharkpanel-${tag}-docker-image.tar.gz"

# 断言本地 tag 与目标版本一致：安装器只认完整引用字符串，tag 对不上会重新拉取
docker images --format '{{.Repository}}:{{.Tag}}' | grep "^ghcr.io/pmat77/bubblesharkpanel:${tag}$"
```

然后原样重跑安装命令。这次镜像已在本地，日志出现 `Runtime image already present locally, skipping pull` 后会一路走完。

</details>

<details>
<summary>指定镜像源、代理或强制重新拉取</summary>

`--network cn` 之外的参数见[参数速查](reference.md#安装器参数)与[镜像与更新](reference.md#镜像与更新)。常用三个：

- `BSP_GITHUB_PROXY=https://gh-proxy.com/`：固定一个加速节点，不再按内置代理池回退；
- `BSP_IMAGE_MIRRORS=mirror.example.com`：改用你控制的镜像源；
- `BSP_FORCE_IMAGE_PULL=1`：本地已有同名镜像也强制重新拉取。

</details>

<details>
<summary>没看到 skipping pull 又在下载，或安装器报 Compose 插件缺失</summary>

**又去下载镜像**：脚本默认 tag 与本地镜像 tag 不一致。两边都要等于 `${tag}`：`sed -n '9p' "install-${tag}.sh"` 与 `docker images | grep bubblesharkpanel`。也可以显式覆盖重跑：

```bash
sudo BSP_RELEASE_TAG="${tag}" bash "install-${tag}.sh" --mode docker --network cn
```

**安装器提示自动补装 Compose 插件失败**（加速节点全不可达或校验不过，报错信息里带手动命令）：手动装好插件再重跑安装命令。

```bash
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fL --retry 3 "https://gh-proxy.com/https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

这里用的是二进制而不是 `apt install docker-compose`：源里那个是 1.x 旧版（命令叫 `docker-compose`），没有安装器需要的 v2 `docker compose` 子命令。

</details>

## 初始密码

管理员名默认 `superadmin`，初始密码由安装器随机生成，安装摘要里会直接打印出来。首次登录会强制改密，改密要求 8-64 位且包含大小写字母、数字与特殊字符。

安装摘要已滚走时，从 `panel.env` 读：

```bash
sudo sed -n 's/^ADMIN_PASSWORD=//p' /opt/bubblesharkpanel/panel.env
```

如果登录提示密码错误，说明容器没收到这个变量（旧版 compose 或手动 `docker run` 漏了 `-e`），改读容器内的凭据文件：

```bash
docker exec bubblesharkpanel-panel cat /app/data/admin-credentials.txt
```

首次登录会拦到改密页，改完凭据文件自动删除。

## 必须开放的端口

| 用途 | 协议 | 默认端口 | 何时需要 |
| --- | --- | --- | --- |
| 面板 Web | TCP | 9527 | 始终需要 |
| 主世界 · 游戏端口 | UDP | 10999 | 始终需要 |
| 主世界 · Steam 认证端口 | UDP | 8766 | 始终需要 |
| 主世界 · Steam 主服端口 | UDP | 12346 | 始终需要 |
| 洞穴 · 游戏端口 | UDP | 11000 | 开启洞穴时需要 |
| 洞穴 · Steam 认证端口 | UDP | 8768 | 开启洞穴时需要 |
| 洞穴 · Steam 主服端口 | UDP | 12348 | 开启洞穴时需要 |

云厂商的安全组默认拒绝入站，要手动放行；游戏端口对全网开放，面板端口建议只对你自己的常用 IP 开放。安装器默认不改本机防火墙，需要时加 `--open-panel-port` / `--open-dst-ports`。

<details>
<summary>宿主服务器在 NAT 转发后面（云平台端口映射 / 路由器映射）</summary>

这种情况只放行安全组不够，还要在平台或路由器上加转发规则，且必须满足两条：

1. 主世界 3 个加洞穴 3 个 UDP **每个都要一条规则**。只映射 10999 是最常见的漏配，表现为能进主世界、一进洞穴就崩线；
2. **外部端口必须等于内部端口**（10999→10999、11000→11000）。游戏会把自己配置文件里的端口上报给 Klei / Steam，玩家从列表进服以及从主世界切进洞穴都按上报端口连接，公网端口被平台改成随机高位就会出现「列表里搜得到、点不进去」。平台只给随机高位端口时，把该实例的分片端口改成平台分配的公网端口号（面板「世界设置 → 网络」）。

分片之间通信用的是 10888，走实例专用 bridge 网络，**不需要对外开放**。

</details>

## 常见错误

| 报错关键词 | 怎么处理 |
| --- | --- |
| 镜像层下载 `net/http: TLS handshake timeout` 或长时间 `Waiting` | 国内最常见的形态：registry 元数据正常、层数据拉不动。`--network cn` 下默认已走离线包；若仍卡在直拉，用 `BSP_IMAGE_SOURCE=offline` 重跑。安装器连续 90 秒无进度会主动中断，不会永久挂住 |
| `Cannot reach GHCR` / `Image pull failed` | 同上。定位用 `curl -I https://ghcr.io/v2/`（返回 401 属正常）；「清单能取到、层下载超时」是网络不可达，不是鉴权问题，重试和换代理都不会成功 |
| `Docker Compose v2 plugin is required but unavailable` | 按报错里的手动命令装插件后重跑安装器，命令见「安装（国内服务器）」的折叠块 |
| 装之前想知道会走哪条路线 | `sudo bash "install-${tag}.sh" --check`：只打印体检报告（系统、架构、内存、磁盘、Docker、GHCR 与 Steam CDN 可达性、端口占用），不改动系统 |
| `download.docker.com` 不可达 | 安装器会自动回退发行版自带的 `docker.io`；apt 慢就加 `--network cn`，其余查 apt 源签名、系统时间与 HTTPS 出站 |
| `checksum mismatch` | 下载内容与 Release 不一致。清掉代理或 CDN 缓存，确认 `BSP_RELEASE_TAG` 与资源 URL 是同一版本 |
| 面板不断重启 | `docker logs --tail 100 bubblesharkpanel-panel` 定位，常见为端口占用、`panel.env` 缺键或数据库权限；修正后 `docker compose up -d panel` |
| 玩家搜不到房间 | 先查安全组是否放行了全部 6 个 UDP 端口，再确认房间没勾「离线」模式、已保存集群令牌 |
| Mod 市场列表取不到 | 面板的 Steam 请求走自己的代理配置，见[参数速查 · Steam 与 Mod 市场](reference.md#steam-与-mod-市场) |
| 从其他面板或裸机迁过来 | 把源机器的集群目录打成压缩包，再用面板「备份与恢复 → 导入外部存档」导入；能自动完成与需手工处理的项目见[从其他面板或裸机迁入](migrate-from-other-panel.md) |

排查时还能用 `bsp doctor` 做一次全面体检，或用 `bsp logs` 跟面板日志。参数与变量见[参数速查](reference.md)。

## 升级

面板内「系统设置 → 面板与游戏版本」两步走：先「下载更新」，再「立即安装」。下载段默认优先取 Release 离线镜像包（走加速代理并校验同名 `.sha256`），失败才回退 GHCR 拉取；下载中断会断点续传，不影响正在运行的面板。

**安装完成后请刷新浏览器页面**（Ctrl/Cmd+Shift+R），否则还在跑升级前的界面脚本。

不想用面板也可以用旧 tag 重跑安装脚本，或把 `panel.env` 的 `PANEL_IMAGE` 指向旧 tag 后执行 `bsp update`——两种都是同模式原地升级，保留数据库、实例、存档与自定义配置，升级前会自动备份数据库。

> 回滚不碰游戏存档，但**旧版本可能不认识新版本迁移过的数据库**。跨版本回滚前先在面板「备份与恢复」页做一次数据库快照。

需要卸载时，先下载备份，再按顺序执行：

```bash
cd /opt/bubblesharkpanel
sudo docker compose --env-file panel.env -f docker-compose.yml -f docker-compose.bind.yml down

# 游戏实例：建议先在面板里逐个删除，再确认没有遗留容器
sudo docker ps -a | grep -i bsp
sudo docker ps -a --filter "name=bsp-" -q | xargs -r sudo docker rm -f

# 确认已备份后再删数据目录（存档、备份与数据库都在这里）
sudo ls /var/lib/bubblesharkpanel
sudo rm -rf /var/lib/bubblesharkpanel /opt/bubblesharkpanel
```
