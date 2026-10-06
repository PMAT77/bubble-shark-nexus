# 宿主机内存与 DST 部署档位

BubbleSharkPanel 支持 **Docker 与 Native systemd 双运行时**。下文的档位与预算按 **Docker 模式** 给出：面板容器 + 每实例 DST 容器（开启洞穴时为 **地上 + 洞穴两个容器**）+ 安装时的 **SteamCMD 临时容器**；Native 模式没有容器与 SteamCMD 子容器开销，但游戏进程本身的内存占用相近。
任务管理器里单个进程只显示几十 MiB 属正常现象，**总占用请看「可用内存」与 `docker stats`**。

---

## 档位对照（按总内存 MemTotal）

| 档位 | 总内存参考 | 单实例（地上） | 洞穴 | Mod（经验值） | 同机多实例 |
|------|------------|----------------|------|---------------|------------|
| **small** | 约 **4 GiB**（&lt; 5 GiB） | ✅ 推荐 | ❌ 不建议 | 少量（≤10） | ❌ 不建议同时运行 |
| **medium** | 约 **6 GiB**（5–8 GiB） | ✅ | ✅ 可开 | 中等（10–30） | 第二实例可用 seed，避免与安装并行 |
| **large** | **≥ 8 GiB** | ✅ | ✅ | 较多 Mod 仍须观察 | 自行规划上限与实例数 |

说明：

- **Mod** 主要增加 **DST 游戏容器** 内存，不是面板进程；Mod 越多，越需要更大内存或设置 `BSP_DST_CONTAINER_MEMORY_MB`。
- **安装 / 更新** Steam 服务端时会短时升高占用；面板默认串行 SteamCMD 任务，但仍建议 **先停止运行中实例** 再安装。
- **开发环境** `pnpm dev:compose` 为双 Node 容器，内存显著高于生产单容器，**不能**用开发占用评估生产。

---

## 典型内存预算（生产、单实例）

以下为经验区间，实际随 Mod、存档、玩家数波动：

| 组件 | 约占用 |
|------|--------|
| Docker 守护进程 + 系统 | 0.3–0.8 GiB |
| panel 容器 | 0.2–0.5 GiB |
| DST 地上 | 0.5–1.5+ GiB |
| DST 洞穴（若开） | +0.4–1.0+ GiB |
| SteamCMD 安装峰值 | +1.0–1.5 GiB（短时） |

因此 **4 GiB 机** 适合「体验开服」；**6 GiB** 适合「地上 + 洞穴 + 中等 Mod」；**8 GiB+** 更适合 Mod 较多的长期服。

---

## 缓存区：小内存机由安装器自动配置

**DST 的内存占用是尖峰型的。** 世界跑起来之后单分片大约 1–1.2 GiB，但**启动时要把整套 Mod 与世界读一遍**，峰值可以到 2 GiB 上下（实测：36 个 Mod 的主世界分片峰值 `anon-rss` 2026 MiB）。4 GiB 的机器装得下稳态，**装不下这个尖峰**——内核会在加载途中直接杀掉分片，`dmesg` 里是：

```
Out of memory: Killed process ... (dontstarve_dedi) anon-rss:2075120kB
```

**表现出来不是「内存不足」，而是「实例显示运行中、大厅却搜不到、也进不去」**，很容易误判成别的问题。

缓存区就是给这个尖峰准备的落点：内存紧张时把冷数据挪到硬盘，尖峰过去再换回来。它不是「让机器变慢」，而是「让尖峰有地方落」。

```bash
sudo bsp setup-swap
```

它会创建 2 GiB 的缓存区文件（`/swapfile-bsp`）、写进 `/etc/fstab`（**重启后仍然有效**），并设置 `vm.swappiness=20`（优先用内存、必要时才换出）与 `vm.min_free_kbytes=100000`。**做一次即可**，之后升级面板、重启实例都不用再管。

**小内存机由安装器自动完成**：`install.linux.sh` 检测到总内存低于 5 GiB 且当前没有缓存区时，会创建同样的缓存区文件 并写入 fstab 与 sysctl，安装摘要里会写明结果。换档规则是总内存低于 3800 MiB 时给 4 GiB，其余小内存机给 2 GiB。关闭方式：`--no-swap` 或 `BSP_SWAP_ON_INSTALL=0`；改大小用 `BSP_SWAP_SIZE`。

**为什么要 root**：创建缓存区需要 root，而面板以普通用户 `bsp` 运行（这是有意的安全设计，面板不应是 root），所以面板做不到这一步。**从旧版本升级上来的机器**（安装时还没这个行为）需要手动执行一次上面的命令。

缓存区文件会占用根分区磁盘空间；余量不足时安装器会跳过并提示，不会写出半途而废的配置。

确认是否已生效：

```bash
swapon --show     # 有输出即已生效；没有任何输出说明还没配
```

### 面板会替你挡一道

启动前按「分片数 ×（512 MiB + 每个启用中的 Mod 32 MiB）」估算峰值，并把**可用缓存区计入可回收余量**。不够时**直接拒绝启动**并提示执行 `bsp setup-swap`，而不是启动到一半被内核杀掉。确需强制放行可在 `panel.env` 设 `BSP_HOST_MIN_AVAILABLE_MB=0`（小内存机慎用）。

加了缓存区仍被拒绝时，按顺序考虑：

1. 把缓存区加到 4 GiB。**`setup-swap` 在检测到已有缓存区时不做任何改动**（直接返回，安装器的自动配置同样跳过），所以要先关掉旧的再重建：

   ```bash
   sudo swapoff /swapfile-bsp
   sudo rm -f /swapfile-bsp
   sudo sed -i '\#^/swapfile-bsp #d' /etc/fstab
   sudo BSP_SWAP_SIZE=4G bsp setup-swap
   ```

2. 关闭洞穴分片——单分片峰值约为双分片的一半
3. 减少订阅的 Mod——占用与 Mod 数量近似线性

关闭洞穴后单分片通常不需要缓存区即可启动（单分片估算约 2 GiB，4 GiB 机器放得下），这是内存最紧张时的保底方案。

---

## panel.env 预设

仓库提供三档可选配置（**非默认强制**）：

| 文件 | 路径 |
|------|------|
| 小内存 | `config/panel.env.presets/small.env` |
| 中等 | `config/panel.env.presets/medium.env` |
| 大内存 | `config/panel.env.presets/large.env` |

安装脚本默认 `BSP_PANEL_ENV_PRESET=auto`，按检测到的总内存自动追加对应预设片段到 `/opt/bubblesharkpanel/panel.env`。

手动指定预设：

```bash
sudo BSP_PANEL_ENV_PRESET=medium bash ./scripts/install.linux.sh
```

已安装后合并预设并重启：

```bash
sudo bash -c 'cat /opt/bubblesharkpanel/config/panel.env.presets/small.env >> /opt/bubblesharkpanel/panel.env'
cd /opt/bubblesharkpanel
sudo docker compose --env-file panel.env -f docker-compose.yml -f docker-compose.bind.yml up -d
```

### 相关环境变量

| 变量 | 含义 |
|------|------|
| `BSP_STEAMCMD_CONTAINER_MEMORY_MB` | SteamCMD 子容器内存硬上限（MiB），不设则不限制 |
| `BSP_STEAMCMD_CONTAINER_MEMORY_SWAP_MB` | SteamCMD 子容器缓存区上限（MiB），预设中与内存上限同值 |
| `BSP_DST_CONTAINER_MEMORY_MB` | 每个 DST 分片容器上限（MiB） |
| `BSP_HOST_STEAMCMD_PLANNING_MB` | 安装 / 更新前的内存规划预留（MiB），参与守卫判断 |
| `BSP_HOST_DST_PLANNING_MB` | DST 启动守卫的单分片规划**下界**（MiB）；实际按「512 + 每个启用中的 Mod 32 MiB」估算，双分片再乘 2 并加余量。**设小不会让守卫更宽松** |
| `BSP_HOST_MEMORY_HEADROOM_MB` | 安装/启动守卫保留空闲（默认 512） |
| `BSP_HOST_MIN_AVAILABLE_MB` | 设为 `0` 可关闭守卫（小内存慎用） |
| `BSP_SWAP_ON_INSTALL` | 安装器在小内存机上自动创建缓存区文件（默认 `1`，设 `0` 关闭；等同 `--no-swap`） |
| `BSP_SWAP_SIZE` | 自动创建或 `bsp setup-swap` 的缓存区大小（默认 `2G`，总内存低于 3800 MiB 时安装器用 `4G`） |
| `BSP_SHARD_READY_WAIT_SEC` | 等待主世界分片就绪的上限秒数（默认 900）；超时会照常启动洞穴分片 |
| `BSP_STEAMCMD_APP_UPDATE_TIMEOUT_MS` | 单次 app_update 超时（毫秒，默认 3600000 = 60 分钟），超时终止后重试断点续传 |

完整示例见仓库根目录 `panel.env.example`。

---

## 安装脚本内存提示

`scripts/install.linux.sh` 在预检阶段读取 `/proc/meminfo`：

- 总内存 **&lt; 约 4 GiB**：输出 **WARN**，说明档位与建议，并写入 `install.status`
- **`BSP_PANEL_ENV_PRESET=auto`**：自动合并 `small` / `medium` / `large` 预设

---

## 面板内提示

登录后：

- **监控台**：展示当前内存档位与总览建议
- **房间设置 → 启用洞穴**：小内存档位显示警告
- **世界设置 → 模组**：提示 Mod 与内存关系
- **实例管理**：创建/安装前提示避免与运行实例叠加
- **实例控制**：运行中还会区分「世界已就绪 / 世界尚未就绪」。进程起来后要加载整套 Mod 与世界才向大厅注册，此期间房间搜不到，列表里带「加载中」、超过等主世界就绪的上限后显示「未就绪」
- **因内存不足启动失败时**：实例上写明结论（例如「该分片被系统按内存上限终止过 N 次」）并给出「增加缓存区」引导——先在面板停止实例，再执行命令，然后重新启动。必须按这个顺序：缓存区正被实例占用时缩容会被系统拒绝，甚至把实例一起杀掉

安装/启动时若可用内存不足，API 会返回 `HOST_MEMORY_PRESSURE` 错误（可在 `panel.env` 调整守卫）。

---

## 面板读数的口径

同一台机器上，面板不同位置与云厂商控制台显示的数字可能不一样——先看口径，再看数值：

| 位置 | CPU | 内存 |
|------|-----|------|
| 监控台、本地节点卡片 | 全核基准（2 核跑满 = 100%），后台每 3 秒采样一次 | 已用 = 总量 − 可用内存；「可用」含可回收的文件缓存，与 `free -h` 的 `available` 同口径 |
| 实例控制卡片 | 单核基准（100% = 占满一个核心），目前只统计主世界分片进程 | 该进程的常驻内存，不含洞穴分片 |
| 云厂商控制台 | 通常是 1 分钟均值，粒度更粗 | 各家口径不一，以 `free -h` 的 `available` 为准 |

四点提醒：

- **内存看「可用」而不是「已用」**：DST 启动会把整套 Mod 与世界读一遍，这些文件缓存随时可回收，`used` 会因此偏高。面板已与启动守卫、`free -h` 的 `available` 统一口径。
- **小内存机看「可用缓冲」**：监控台内存卡片上的「可用缓冲 = 可用内存 + 缓存区余量」，才是启动新分片前真正能用的部分；低于 0.5 GB 标红。只盯内存占用百分比，会把「内存吃满但有缓存区兜底」和「内存与缓存区都见底」看成同一件事。
- **CPU 不要跨位置比大小**：实例卡片是单核基准、监控台是全核基准，两者差一个「核数」的系数。
- **「归一化占用率」不是 CPU 使用率**：它是 `1 分钟负载 ÷ 核数`，反映的是排队压力。

---

## 运维排查

**实例起不来，或「显示运行中但大厅搜不到／进不去」**——先排除内存尖峰，三条命令：

```bash
free -h                                          # 看 available 还有多少
swapon --show                                    # 没有输出说明没有缓存区：小内存机看安装摘要（自动创建失败或磁盘不足），其余机器执行 sudo bsp setup-swap
sudo dmesg -T | grep -iE 'killed process|oom'    # 有输出即确实被内核 OOM 杀掉
```

面板的实例详情会直接写出原因（如「内存不足被系统终止（该分片上限 N MiB）」「主世界分片反复重启（已重启 N 次）」），一般不用登录服务器判断。分片自己的输出（含完整启动与报错）在实例目录的 `klei-storage/DoNotStarveTogether/Cluster_1/<Master|Caves>/server_log.txt`，面板控制台也能看到。

```bash
free -h

# Docker 模式
docker stats --no-stream
docker logs --tail 100 bubblesharkpanel-panel

# Native 模式（没有容器，游戏分片是 bsp 用户的 systemd 服务）
sudo systemctl status bubblesharkpanel.service --no-pager
sudo journalctl -u bubblesharkpanel.service -n 100 --no-pager
```

Docker 模式下 SteamCMD 容器 exit 137 有两种来源（Native 模式无容器，对应的是安装任务超时与宿主机 OOM）：

- **面板超时终止**：单次 app_update 超过 `BSP_STEAMCMD_APP_UPDATE_TIMEOUT_MS`（默认 60 分钟）后由面板 SIGKILL，日志含 `GSH-STEAMCMD-TIMEOUT`。此时与内存无关，调大该值即可；已下载内容保留，重试会自动断点续传。
- **内存不足**：容器硬上限或宿主机 OOM。可调高预设或升级规格，并避免安装与多实例同时运行。

更多安装步骤见 [Docker 模式安装](install-docker.md)与 [Native systemd 模式安装](install-native.md)。
