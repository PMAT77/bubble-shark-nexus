# 参数速查

安装器参数与面板环境变量速查。装的时候用上面的[安装器参数](#安装器参数)与[安装选项](#安装选项)，装完之后改面板行为用下面的[面板环境变量](#访问与地址)（改的是 `/opt/bubblesharkpanel/panel.env`，改完 `bsp restart` 生效）。

跳转：[安装器参数](#安装器参数) · [安装选项](#安装选项) · [访问与地址](#访问与地址) · [账号与安全](#账号与安全) · [镜像与更新](#镜像与更新) · [内存与资源](#内存与资源) · [存储与备份](#存储与备份) · [网络与下载](#网络与下载) · [Steam 与 Mod 市场](#steam-与-mod-市场)

## 安装器参数

| 参数 | 取值 | 用途 |
| --- | --- | --- |
| `--mode` | `auto` / `docker` / `native` | 部署模式。管道安装时 `auto` 等于 Docker，**建议显式指定** |
| `--network` | `auto` / `cn` / `global` | 网络档位。`cn` 临时切国内软件源、把 SteamCMD 重试提到 8 次，失败自动还原 |
| `--open-panel-port` | — | 安装时在本机防火墙放行面板端口（默认 9527/tcp） |
| `--open-dst-ports` | — | 安装时在本机防火墙放行 6 个 DST UDP 端口 |
| `-h`, `--help` | — | 打印全部参数与支持的变量 |

<details>
<summary>注意：安装器默认不改防火墙</summary>

加了 `--open-*` 也只影响本机防火墙（ufw / firewalld），云厂商安全组永远要手动放行。宿主服务器在 NAT 后面时，还要在平台或路由器上按**与内部相同的端口**逐条添加转发规则。

</details>

## 安装选项

在安装命令前用 `sudo env 变量=值` 传入，或用 `--mode` / `--network` 参数代替前两项。

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_INSTALL_MODE` | `auto` | 同 `--mode` |
| `BSP_NETWORK_PROFILE` | `auto` | 同 `--network` |
| `BSP_RELEASE_TAG` | 脚本内置 `v0.19.0` | 安装指定版本。升级时填**目标**版本 |
| `BSP_PANEL_ENV_PRESET` | `auto` | 内存预设档位：`auto` / `small` / `medium` / `large` / `none` |
| `PANEL_IMAGE` | GHCR 当前 tag | 统一镜像的完整引用（tag 或 digest），自建仓库时用 |
| `INSTALL_STEAMCMD_IMAGE` | `1` | 设 `0` 跳过预拉 SteamCMD 镜像 |
| `USE_CN_DEBIAN_MIRROR` | `0` | 设 `1` 让 apt 优先走国内镜像 |
| `BSP_GITHUB_PROXY` | 内置代理池 | 固定一个 GitHub 加速代理，如 `https://gh-proxy.com/` |
| `ADMIN_USERNAME` | `superadmin` | 初始管理员用户名 |
| `ADMIN_PASSWORD` | 随机生成 | 初始管理员密码。留空时面板生成随机强密码 |
| `HIDE_ADMIN_PASSWORD` | `0` | 设 `1` 时不在安装摘要里打印初始密码（输出会被重定向到文件时用） |
| `STRICT_INSTALLER_ASSET_CHECKSUM` | `1` | 安装资源校验和强校验，**不建议关** |
| `PANEL_INSTALL_DIR` | `/opt/bubblesharkpanel` | 安装目录（放 `panel.env` 与 compose 文件） |
| `PANEL_DATA_DIR` | `/var/lib/bubblesharkpanel` | 数据目录（数据库、实例、备份） |
| `PANEL_LOG_DIR` | `/var/log/bubblesharkpanel` | 日志与安装状态目录 |

<details>
<summary>注意：内存不改预设也能跑，小内存机的缓存区由安装器自动配置</summary>

总内存低于 5 GiB 且当前没有缓存区时，安装器会自动创建缓存区文件 并写进 `/etc/fstab`（重启后仍生效）；总内存低于 3800 MiB 给 4 GiB，其余小内存机给 2 GiB。用 `--no-swap` 或 `BSP_SWAP_ON_INSTALL=0` 关闭，大小用 `BSP_SWAP_SIZE` 指定。面板不以 root 运行，做不到这一步，所以从旧版本升级上来的机器仍需执行一次 `sudo bsp setup-swap`。

分片加载整套 Mod 时内存会短时冲高，物理内存不足会让内核在加载途中直接杀掉分片，表现为「实例显示运行中但大厅搜不到」。档位与预设见[内存档位](MEMORY.md)。

</details>

## 访问与地址

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `PANEL_PORT` | `9527` | 面板对外端口。改完要先在安全组放行新端口 |
| `PANEL_PUBLIC_URL` | 自动探测 | 显式指定对外访问地址（域名或公网 IP），设置后跳过一切探测 |
| `PANEL_HOST` | 自动探测 | 显式指定面板主机地址，同样跳过探测 |
| `BSP_PANEL_AUTO_PUBLIC_IP` | `1` | 设 `0` 关闭对外 IP 自动探测 |
| `BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS` | `3` | 对外 IP 探测的总耗时预算（秒） |

<details>
<summary>自动探测的顺序与来源标注</summary>

顺序是「显式指定 → 网卡公网地址 → 云平台元数据 → 出站 IP 探测 → 本机地址」，安装摘要会在括号里标出这一行的来源。标为「出站 IP 探测」的地址是出口地址，只在该公网 IP 已映射到本机端口时可用；NAT 机器上探测不到公网地址时会显示内网地址并注明「仅同一局域网可访问」。

</details>

## 账号与安全

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `ADMIN_USERNAME` | `superadmin` | 管理员账号名。公网部署建议改掉默认值 |
| `ADMIN_PASSWORD` | 随机生成 | 管理员初始密码，从 `panel.env` 读取 |
| `FORCE_PASSWORD_CHANGE` | `1` | 首次登录强制改密 |
| `BSP_PASSWORD_RECOVERY_TOKEN` | 空 | 设成至少 16 位的随机串后，登录页「忘记密码」可在线上重置 |
| `BSP_SYNC_ADMIN_PASSWORD_FROM_ENV` | `0` | 设 `1` 把 `ADMIN_PASSWORD` 写回数据库并重启，用完改回 `0` |
| `BSP_GUEST_LOGIN_ENABLED` | `0` | 只读游客免密预览入口 |
| `BSP_GUEST_LOGIN_ACCOUNT` | `guest` | 游客账号名，不允许与 `ADMIN_USERNAME` 相同 |

<details>
<summary>游客预览的三条硬前提</summary>

1. **只有 Native 模式会生效**。Docker 模式下面板挂着 `docker.sock`，一次有效登录等价于宿主机 root，面板会拒绝开放并在启动日志里说明原因；
2. **必须在反向代理层再加一层访问控制**（IP 白名单、Basic Auth 或 VPN），别把面板裸在公网；
3. **只读不等于看不到东西**：实例目录与文本文件、房间与世界配置、玩家名单（含管理员名单）、在线玩家、备份列表与控制台日志都对访客可见。

完整说明见 [SECURITY.md](../SECURITY.md) 的游客角色一节。

</details>

## 镜像与更新

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `PANEL_IMAGE` | `ghcr.io/pmat77/bubblesharkpanel:v0.19.0` | 统一镜像引用，自建仓库或固定 digest 时用 |
| `BSP_IMAGE_SOURCE` | `auto` | 安装阶段取运行时镜像的路线：`auto`（国内档或层数据不可达时用离线包，否则直拉）/ `offline`（固定离线包）/ `native`（固定 GHCR 直拉） |
| `BSP_FORCE_IMAGE_PULL` | `0` | 设为 `1` 时即使本地已有同名镜像也重新拉取 |
| `DOCKER_PULL_STALL_SECONDS` | `90` | 直拉时连续多少秒没有进度就判定停滞并放弃本次尝试 |
| `GHCR_LAYER_PROBE_MAX_SECONDS` | `20` | 体检里测 GHCR 层数据可用性的单次请求上限；慢于此值即判为不可用 |
| `BSP_IMAGE_MIRRORS` | 空 | 备选 registry 候选，逗号分隔、按顺序尝试（面板运行时拉游戏镜像用） |
| `BSP_GITHUB_PROXY` | 内置代理池 | Release 离线镜像包的加速代理，留空则按代理池依次尝试 |
| `BSP_GITHUB_API_BASE` | `https://api.github.com` | 「检查更新」用的 GitHub API 基址，直连超时时指向兼容反代 |
| `BSP_PANEL_UPDATE_SOURCE` | `auto` | 「下载更新」的下载源：`auto` / `offline`（只用离线包）/ `pull`（只用 GHCR） |
| `BSP_PANEL_UPDATER_IMAGE` | 空 | 面板内更新的 updater 容器镜像；留空自动挑选，离线部署无需设置 |

安装阶段选路线时会先实测 GHCR 的层数据能不能拉：**registry 元数据可达（`/v2/` 返回 401）不等于层数据可达**，国内常见的是元数据正常、层下载长时间 `Waiting`。这条路测不通就走 Release 离线镜像包，并可用 `BSP_IMAGE_SOURCE` 强制指定。

面板里的「系统设置 → 面板与游戏版本」选择优先于这里的默认值。

## 内存与资源

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_PANEL_ENV_PRESET` | 安装器写入 | 内存预设档位，见仓库 `config/panel.env.presets/` |
| `BSP_STEAMCMD_CONTAINER_MEMORY_MB` | 不限制 | SteamCMD 子容器内存硬上限（MiB） |
| `BSP_STEAMCMD_CONTAINER_MEMORY_SWAP_MB` | 不限制 | 同上，缓存区上限，让安装尖峰有地方落 |
| `BSP_DST_CONTAINER_MEMORY_MB` | 不限制 | 游戏分片容器内存硬上限（MiB） |
| `BSP_DST_CONTAINER_CPU_QUOTA` | 不限制 | 单个分片的 CPU 配额 |
| `BSP_HOST_STEAMCMD_PLANNING_MB` | `1280` | 安装前守卫按这个值预留可用内存 |
| `BSP_HOST_DST_PLANNING_MB` | `512` | 分片启动守卫的单分片规划下界（MiB） |
| `BSP_HOST_MEMORY_HEADROOM_MB` | `512` | 守卫额外留的余量（MiB） |
| `BSP_HOST_MIN_AVAILABLE_MB` | 不设置 | 设为 `0` 关闭启动前的内存守卫（小内存慎用） |
| `BSP_SWAP_ON_INSTALL` | `1` | 安装器在小内存机上自动创建缓存区文件，设 `0` 关闭（等同 `--no-swap`） |
| `BSP_SWAP_SIZE` | `2G` | 自动创建或 `bsp setup-swap` 的缓存区大小；总内存低于 3800 MiB 时安装器用 `4G` |

<details>
<summary>启动守卫怎么估算，以及为什么建议用预设文件而不是手抄</summary>

守卫按「分片数 ×（512 MiB + 每个启用中的 Mod 32 MiB）」估算，并把可用缓存区计入可回收余量；不够时直接拒绝启动并给出建议，而不是启动到一半被内核杀掉。档位说明与推荐预设见[内存档位](MEMORY.md)。

</details>

## 存储与备份

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_STACK_DIR` | `/opt/bubblesharkpanel` | 面板栈目录，`bsp` CLI 与面板内更新按它定位 compose 文件 |
| `BSP_COMPOSE_FILES` | `docker-compose.yml:docker-compose.bind.yml` | 面板栈使用的 compose 文件，冒号分隔 |
| `BSP_BACKUPS_ROOT` | 数据目录下的 `backups` | 备份根目录（存档包与数据库快照） |
| `BSP_MOD_IMPORT_ROOT` | 系统临时目录下的 `bsp-mod-import` | Mod ZIP 预览目录，绑定上传用户与实例，有效期 1 小时 |
| `BSP_MOD_IMPORT_MAX_ARCHIVE_BYTES` | 实例文件上传上限（默认 256 MiB） | 本地 Mod ZIP 上传字节上限 |
| `BSP_MOD_IMPORT_MAX_EXTRACTED_BYTES` | `1073741824`（1 GiB） | Mod ZIP 解压字节上限 |
| `BSP_MOD_IMPORT_MAX_FILES` | `50000` | Mod ZIP 文件与目录条目上限 |
| `BSP_MOD_IMPORT_MAX_DEPTH` | `32` | Mod ZIP 条目路径最大层数 |
| `BSP_INSTALL_SEED_ENABLED` | `1` | 同机第二个实例从已停止实例复制游戏文件，跳过重复下载 |
| `BSP_INSTALL_DEFER_DST_IMAGE_PULL` | 已弃用 | 配置已忽略；安装完成前始终准备 DST 运行镜像 |

## 网络与下载

只有 GitHub Raw、GitHub Release 与 SteamCMD 需要出网时才有用。

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_GITHUB_PROXY` | 内置代理池 | 固定一个加速代理，安装与面板内更新共用 |
| `BSP_NATIVE_RELEASE_MIRRORS` | 安装器生成 | Native Release 下载源，逗号分隔的目录前缀 |
| `BSP_NATIVE_RELEASE_ARCHIVE` | 空 | 用本地 Native 包安装（配合旁边的同名 `.sha256`） |
| `BSP_NATIVE_RELEASE_SHA256` | 空 | 本地包旁没有 `.sha256` 时手工给出摘要 |
| `BSP_NATIVE_STEAMCMD_URL` | `steamcdn-a.akamaihd.net` | Native 模式的 SteamCMD 下载地址 |
| `BSP_NATIVE_UPDATE_DIR` | 数据目录下的 `panel-update` | Native 面板内更新的请求与状态交换目录 |
| `BSP_STEAMCMD_NETWORK_MODE` | 空 | 持续被 CDN 超时时可设 `host` 换网络模式 |

## Steam 与 Mod 市场

面板自身的 Steam 请求与 SteamCMD 是**两套配置**：上面这组管 Mod 市场列表与详情，下面这组管游戏与 Mod 文件的下载。

| 变量 | 默认 | 用途 |
| --- | --- | --- |
| `BSP_STEAM_HTTPS_PROXY` | 空 | 面板侧代理。Docker 模式下代理在宿主机时写 `http://host.docker.internal:7890` |
| `BSP_STEAM_WEBAPI_BASE_URL` | 官方 | `api.steampowered.com` 的反代，**带路径前缀时结尾必须加 `/`** |
| `BSP_STEAM_COMMUNITY_BASE_URL` | 官方 | `steamcommunity.com` 的反代 |
| `BSP_STEAM_WEBAPI_KEY` | 空 | 用官方 Web API 拉列表，稳定性高于页面抓取 |
| `BSP_STEAM_RELAY_URL` | 空 | 完全连不上 Steam 时走海外中继 |
| `BSP_STEAMCMD_DOWNLOAD_REGION` | 不设置 | 已废弃；旧配置兼容读取并忽略，下载节点由 SteamCMD 自动选择 |
| `BSP_STEAMCMD_INSTALL_MAX_ATTEMPTS` | `5` | 安装重试次数，最多 20；国内建议 `8` |
| `BSP_STEAMCMD_APP_UPDATE_TIMEOUT_MS` | `3600000` | 单次 app_update 超时（毫秒），大体积游戏慢链路上调到 2 小时 |
| `BSP_STEAMCMD_HTTPS_PROXY` | 空 | SteamCMD 侧代理配置；游戏 CDN 是否走代理需实际验证。桥接容器访问宿主机代理使用 `host.docker.internal`，`127.0.0.1` 指容器自己 |
| `BSP_STEAMCMD_INSTALL_RETRY_DELAYS_MS` | `4000,8000,8000,8000` | 每次重试前的等待毫秒数，逗号分隔 |

<details>
<summary>连不上 Steam 时面板会怎样</summary>

Mod 市场列表会退回最近一次成功拉取的内容（默认 7 天内），界面上标注「离线数据 · 最后更新于 X」；单个请求最多等 10 秒。要确认当前实际生效的链路与代理状态，看面板「系统设置 → 环境自检」里的「Mod 市场上游」一项。

</details>

---

完整键名与逐条注释见仓库根目录 [`panel.env.example`](../panel.env.example)，内存档位的推荐取值见[内存档位](MEMORY.md)。本页与脚本默认值不一致时，以 `sudo bash ./scripts/install.linux.sh --help` 的输出为准。
