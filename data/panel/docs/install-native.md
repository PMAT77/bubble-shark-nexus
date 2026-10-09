# Native systemd 模式安装

面板是系统级 systemd 服务，游戏分片是 `bsp` 用户的 systemd 服务。不装 Docker，也不用 tmux、screen 或 PM2。适合个人服主。

**环境要求**：Debian 12 或 Ubuntu 22.04 / 24.04（只支持 apt 系），root 或 sudo，x86_64，至少 4 GiB 内存，根分区至少 4 GiB 空闲——游戏本体要数 GB，另外要给存档备份留地方。安装器会装 32 位运行库（`libcurl4:i386` 等），DST 与 SteamCMD 需要。

小内存机的缓存区由安装器自动配置（总内存低于 5 GiB 且当前没有缓存区时创建 swapfile 并写进 `/etc/fstab`，`--no-swap` 可关闭）；从旧版本升级上来的机器可手动执行 `sudo bsp setup-swap`。档位参考[内存档位](MEMORY.md)。Windows 不是部署目标，只用于本机开发调试。

## 安装（海外机器）

一条命令装完。

```bash
curl -fsSL "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/v0.16.0/scripts/install.linux.sh" \
  | sudo bash -s -- --mode native
```

管道安装的默认模式是 Docker，**Native 必须显式写 `--mode native`**。GitHub Raw 慢的话，把 `https://raw.githubusercontent.com` 换成 `https://gh-proxy.com/https://raw.githubusercontent.com`。

安装器按顺序做这些事：装基础依赖与 32 位运行库 → 创建 `bsp` 系统用户并开启 linger → 下载校验 Native Release（自带 Node 运行时）→ 解压到 `/opt/bubblesharkpanel/releases/v0.16.0` 并原子切换 `current` 符号链接 → 装 SteamCMD → 写 `panel.env` → 启动面板并等待健康检查。

## 安装（国内服务器）

Native 不拉容器镜像，境外依赖只有两处：GitHub Raw（安装器组件）与 GitHub Release（Native 包）。安装器自带加速代理池（`gh-proxy.com`、`ghfast.top`、`ghproxy.com`），全部失败才走直连，国内一般可以直接装。先把脚本下载到本地更稳妥：

```bash
tag=v0.16.0
curl -fL --retry 3 -o "install-${tag}.sh" \
  "https://gh-proxy.com/https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/${tag}/scripts/install.linux.sh"

# 自证版本：必须输出 ...:-v0.16.0}}，对不上就停下排查
grep '^BSP_RELEASE_TAG=' "install-${tag}.sh"

# 安装：--network cn 把 apt 源临时切到国内镜像，SteamCMD 走 cn 区域并重试 8 次
sudo env BSP_RELEASE_TAG="${tag}" bash "install-${tag}.sh" --mode native --network cn
```

想固定单一代理加 `BSP_GITHUB_PROXY=https://gh-proxy.com/`；想自己列镜像源用 `BSP_NATIVE_RELEASE_MIRRORS=源1,源2`，每项是目录前缀，安装器会接上文件名。apt 国内镜像连不上时，安装器会自动还原系统默认源后重试，不需要手工改回。

<details>
<summary>加速代理全部不可用：手动下载 Native 包再装</summary>

包旁必须放同名 `.sha256`，也可以用 `BSP_NATIVE_RELEASE_SHA256` 直接给出摘要。

```bash
tag=v0.16.0
base="https://gh-proxy.com/https://github.com/PMAT77/bubble-shark-panel/releases/download/${tag}"
curl -fL --retry 3 -o "bubblesharkpanel-native-${tag}-linux-x64.tar.gz"        "${base}/bubblesharkpanel-native-${tag}-linux-x64.tar.gz"
curl -fL --retry 3 -o "bubblesharkpanel-native-${tag}-linux-x64.tar.gz.sha256" "${base}/bubblesharkpanel-native-${tag}-linux-x64.tar.gz.sha256"
sha256sum -c "bubblesharkpanel-native-${tag}-linux-x64.tar.gz.sha256"

sudo env BSP_RELEASE_TAG="${tag}" \
  BSP_NATIVE_RELEASE_ARCHIVE="$(pwd)/bubblesharkpanel-native-${tag}-linux-x64.tar.gz" \
  bash "install-${tag}.sh" --mode native --network cn
```

</details>

## 初始密码与服务命令

```bash
# 初始密码：安装摘要里已打印；管理员名 superadmin，首登强制改密
sudo sed -n 's/^ADMIN_PASSWORD=//p' /opt/bubblesharkpanel/panel.env

# 健康检查：服务应为 active，runtime.status 应为 running
systemctl is-active bubblesharkpanel.service
curl -fsS http://127.0.0.1:9527/health
bsp doctor
```

面板日志用 `sudo journalctl -u bubblesharkpanel.service -f` 跟踪。游戏分片的日志不进 journald，直接写到实例目录下的控制台日志文件，在面板里看或下载。

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

Native 模式下游戏进程直接监听宿主机端口，没有容器这一层。分片之间通信用的是 10888，**不需要对外开放**。

</details>

## 常见错误

| 报错关键词 | 怎么处理 |
| --- | --- |
| `Native Release ... missing` | Release 里没有对应版本的包与 `.sha256`。换已发布版本，或用 `BSP_NATIVE_RELEASE_ARCHIVE` 指定本地包 |
| GitHub Raw / Release 取不到 | 换加速代理前缀重试；仍不通就手动下载脚本与包，见上面的折叠块 |
| `systemd user manager` / `Failed to connect to bus` | 用户的 systemd 实例没起来，按下面的命令修复。**不要用 tmux、screen 或 PM2 绕过**，那会破坏日志、自恢复与资源限制语义 |
| `has a bad unit file setting` | systemd 不说是哪一行。分片 unit 在数据目录下，用用户实例解析它：`sudo -u bsp env XDG_RUNTIME_DIR=/run/user/$(id -u bsp) systemd-analyze --user verify <unit 路径>`。**启动失败后 unit 会被删掉，要尽快看** |
| 实例启动后立刻退出 | 常见为集群令牌失效、Mod 下载不全、内存不足。面板的实例详情会直接写出原因（如「内存不足被系统终止」），一般不用登录服务器判断 |
| Docker 与 Native 混装报 `cross-mode migration is not supported` | 两种模式之间不自动迁移。保留数据目录后按目标模式重装，再手工迁移 `/var/lib/bubblesharkpanel` 下的数据 |
| 玩家搜不到房间 | 先查安全组是否放行了全部 6 个 UDP 端口，再确认房间没勾「离线」模式、已保存集群令牌 |
| Mod 市场列表取不到 | 面板的 Steam 请求走自己的代理配置，见[参数速查 · Steam 与 Mod 市场](reference.md#steam-与-mod-市场) |
| 从其他面板或裸机迁过来 | 把源机器的集群目录打成压缩包，再用面板「备份与恢复 → 导入外部存档」导入；能自动完成与需手工处理的项目见[从其他面板或裸机迁入](migrate-from-other-panel.md) |

`systemd user manager` 那一类的修复命令：

```bash
sudo loginctl enable-linger bsp
BSP_UID="$(id -u bsp)"
sudo systemctl restart "user@${BSP_UID}.service"
sudo systemctl restart bubblesharkpanel.service
sudo loginctl show-user bsp -p Linger
```

内存告警、OOM 判断与档位建议见[内存档位](MEMORY.md)，参数与变量见[参数速查](reference.md)。

## 升级与卸载

面板内「系统设置 → 面板与游戏版本」同样提供「下载更新 → 立即安装」：面板负责下载 Native Release 包并显示进度，后台更新程序以 root 执行官方安装器完成安装、切换版本与重启。更新期间面板短暂无法访问（通常 1～3 分钟），游戏实例不受影响。

**安装完成后请刷新浏览器页面**（Ctrl/Cmd+Shift+R）。如果面板提示「当前安装还没有面板内更新组件」，用目标版本重跑一次安装命令即可获得；只接受升级，同版本重装与降级都会被拒绝，失败会自动回滚到上一个版本。

```bash
sudo journalctl -u bubblesharkpanel-update.service -n 100 --no-pager   # 后台更新程序日志
```

需要卸载时，先下载备份。`current` 是指向 `/opt/bubblesharkpanel/releases/<版本>` 的符号链接，主动降级就是把它切回旧版本：

```bash
sudo systemctl stop bubblesharkpanel.service
sudo ln -sfn /opt/bubblesharkpanel/releases/v0.2.0 /opt/bubblesharkpanel/current.rollback
sudo mv -Tf /opt/bubblesharkpanel/current.rollback /opt/bubblesharkpanel/current
sudo systemctl start bubblesharkpanel.service
```

```bash
# 卸载面板：停止服务与全部分片、关掉 linger、删单元文件
sudo systemctl stop bubblesharkpanel.service
sudo systemctl disable bubblesharkpanel.service
BSP_UID="$(id -u bsp)"
sudo -u bsp XDG_RUNTIME_DIR="/run/user/${BSP_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${BSP_UID}/bus" \
  systemctl --user stop 'bsp-*.service'   # 分片单元名为 bsp-<实例UUID>-<master|caves>.service
sudo loginctl disable-linger bsp
sudo rm -f /etc/systemd/system/bubblesharkpanel.service && sudo systemctl daemon-reload

# 面板内更新的触发单元与后台更新程序（没装过可跳过）
sudo systemctl disable --now bubblesharkpanel-update.path 2>/dev/null || true
sudo rm -f /etc/systemd/system/bubblesharkpanel-update.path \
  /etc/systemd/system/bubblesharkpanel-update.service \
  /usr/local/lib/bubblesharkpanel/bsp-native-update
sudo systemctl daemon-reload

# 确认已备份后再删数据目录
sudo ls /var/lib/bubblesharkpanel
sudo rm -rf /opt/bubblesharkpanel /var/lib/bubblesharkpanel /var/log/bubblesharkpanel
sudo userdel -r bsp                     # 确认不再需要 bsp 用户时执行
```

> 回滚不碰游戏存档，但**旧版本可能不认识新版本迁移过的数据库**。跨版本回滚前先在面板「备份与恢复」页做一次数据库快照。
