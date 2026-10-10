# 宿主机内存与 DST 部署档位

BubbleSharkPanel 支持 **Docker 与 Native systemd 双运行时**。面板计量整个服务或容器，主世界与洞穴分别计量，并在支持的宿主机上归属同一个游戏内存池。安装时的 SteamCMD 占用也需要保留余量。

---

## 档位对照（按总内存 MemTotal）

| 档位 | 总内存参考 | 新安装每片硬限 | 运行建议 |
|------|------------|----------------|----------|
| **small** | &lt; **5120 MiB** | **3072 MiB** | 无 swap 时首装创建 3 GiB；MemTotal &lt; 3800 MiB 时创建 4 GiB |
| **medium** | **5120–8191 MiB** | **4096 MiB** | 无 swap 时首装创建 2 GiB；避免安装与运行并行 |
| **large** | **≥ 8 GiB** | 不设置 | 自行规划每片上限、实例数与安装余量 |

说明：

- **Mod** 主要增加 DST 游戏进程内存；需求取决于 Mod 内容、存档与玩家数，数量只能粗估。4 GiB 配置 2–3 GiB swap 的用户实测可启动 30–40 个 Mod，具体配置仍需观察峰值。
- **硬限按需使用**：两片不会预先占满各自硬限；两片和同机实例共享物理预算与宿主 swap。
- **实例控制 → 资源与启动设置**可分别调整主世界、洞穴硬限，或继承全局配置；保存后下次启动生效，升级不覆盖已有 `panel.env` 和手动设置。
- **安装 / 更新** Steam 服务端时会短时升高占用；面板默认串行 SteamCMD 任务，但仍建议 **先停止运行中实例** 再安装。
- **开发环境** `pnpm dev:compose` 为双 Node 容器，内存显著高于生产单容器，**不能**用开发占用评估生产。

---

## 典型内存预算（生产、单实例）

新安装在支持的宿主机上配置游戏共享物理内存池。预留量取 `max(1024 MiB, 面板峰值 × 1.5 + 512 MiB, BSP_HOST_MEMORY_HEADROOM_MB)`，向上取整至 256 MiB；面板峰值未知时按 512 MiB 估算并显示来源。游戏共享硬限为 `MemTotal − 预留量`，swap 不计入物理硬限。

Native 使用共同用户 slice；标准 Docker 部署使用宿主 slice，需要本机 rootful Docker、systemd 与 cgroup v2。远程 Docker、rootless 或宿主来源无法核验时显示保护缺失，按已有分片配置启动。

旧部署启用共享预算、或重新计算预留量时，先停止同机所有游戏分片，再在宿主机执行：

```bash
sudo bsp setup-memory-budget
```

命令计量整个面板服务或容器、验证内存控制器与实际父级限制。分片下次启动加入共享池；运行期间不会自动降低共享硬限，已有分片硬限仍保留。

占用随 Mod、存档、玩家数波动，表中区间仅用于初步规划：

| 组件 | 约占用 |
|------|--------|
| Docker 守护进程 + 系统 | 0.3–0.8 GiB |
| panel 容器 | 0.2–0.5 GiB |
| DST 地上 | 0.5–1.5+ GiB |
| DST 洞穴（若开） | +0.4–1.0+ GiB |
| SteamCMD 安装峰值 | +1.0–1.5 GiB（短时） |

总内存档位用于选择起始配置，实际可运行规模取决于宿主机可用内存、swap 余量和分片实测峰值。

---

## 缓存区：小内存机由安装器自动配置

**DST 启动会出现内存峰值，完整就绪后占用可能回落。** 启动报告在全部世界就绪时冻结采样峰值，运行后的内核峰值单独显示。触及硬限的峰值仅是需求下界，推荐值同时考虑同次采样的 RAM＋swap。宿主机内存或分片硬限不足时，内核可能终止游戏进程，`dmesg` 中可见：

```
Out of memory: Killed process ... (dontstarve_dedi) anon-rss:2075120kB
```

进程已启动不代表世界已就绪。面板在加载完成及洞穴互联确认前显示启动阶段；OOM、Lua 致命错误与确认退出会立即报告失败。

面板每 5 秒采集加载与运行期间的压力。确认本轮 OOM 时立即保护停止整个实例；分片或共享池达到实际硬限或遗留软限的 95%、持续新增回收事件、内存 PSI 完全停顿比例达到 20%，连续至少 15 秒时也会保护停止。加载期间还要求同期没有有效进展；短暂触顶、正常换页、单纯静默和未知指标不会据此停机。宿主余量持续不足且严重停顿时，优先停止正在加载的实例，否则选择物理占用最大的受管实例。

保护停止保存实际限制、占用与 swap 现场，发布一次异常通知。计划任务、插件与面板恢复不会解除保护；清理完成、余量检查通过后，可直接手动启动或重启。清理失败时保留错误与进程引用，禁止开始新一轮。运行中不会自动创建 swap 或提高限额。

swap 可将部分内存页换出到磁盘，为加载峰值提供缓冲；频繁换页会增加启动耗时。Native 与 Docker 的 DST 分片均可使用宿主机已有的共享 swap，不由面板创建，也不保证抵消过低的硬限。

```bash
sudo bsp setup-swap
```

默认创建 2 GiB swapfile（`/swapfile-bsp`），写入 `/etc/fstab`，并设置 `vm.swappiness=20` 与 `vm.min_free_kbytes=100000`。已有任意 active swap 时，未指定新路径的命令直接返回；重复指定 active 目标同样直接返回。已有但未 active 的目标文件禁止覆盖。

**首装自动配置**：MemTotal 低于 3800 MiB 时创建 4 GiB，3800–5119 MiB 创建 3 GiB，5120–8191 MiB 创建 2 GiB；已有 active swap 保留。安装摘要显示实际目标容量。`--no-swap` 或 `BSP_SWAP_ON_INSTALL=0` 可关闭；显式 `BSP_SWAP_SIZE` 优先于档位。

**为什么要 root**：创建缓存区需要 root，而面板以普通用户 `bsp` 运行（这是有意的安全设计，面板不应是 root），所以面板做不到这一步。**从旧版本升级上来的机器**（安装时还没这个行为）需要手动执行一次上面的命令。

缓存区文件会占用根分区磁盘空间；余量不足时安装器会跳过并提示，不会写出半途而废的配置。

确认是否已生效：

```bash
swapon --show     # 有输出即已生效；没有任何输出说明还没配
```

### 启动前的资源检查

守卫按「512 MiB + 每个启用中的 Mod 32 MiB」、`BSP_HOST_DST_PLANNING_MB` 下界和已有启动实测需求估算新增分片，再加用户保留余量；低硬限不会截断估算。分别检查宿主可用内存与游戏池余量，再考虑可用 swap。`MemAvailable` 已扣除面板当前占用，不重复扣减。主世界就绪后启动洞穴前只检查新增洞穴。`BSP_HOST_MIN_AVAILABLE_MB=0` 关闭余量守卫，保留内核硬限。

面板推荐硬限取「Mod 估算、2048 MiB 基线、最近实测 RAM＋swap 需求及内核峰值」的最大值，加 20% 后向上取整到 256 MiB。推荐值需手动应用；受限测量标为需求下界，不承诺特定 Mod 数量一定可启动。

加了缓存区仍被拒绝时，按顺序考虑：

1. 追加新 swapfile，保留正在使用的旧文件。命令中的大小是新增容量，文件路径必须未存在；先确认磁盘余量：

   ```bash
   sudo BSP_SWAP_SIZE=2G BSP_SWAP_FILE=/swapfile-bsp-extra bsp setup-swap
   ```

2. 停止其他实例或暂时关闭洞穴，释放共享余量。
3. 对照最近启动报告调整分片硬限，排查大型 Mod 与存档的峰值。

未配置 swap 时建议先增加 2–3 GiB 缓冲并复测；已有 swap 但余量不足或用满时，建议追加至少 2 GiB，或按面板显示的预算缺口增加容量。swap 由 root 管理，面板仅展示状态和命令建议。

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
| `BSP_STEAMCMD_CONTAINER_MEMORY_SWAP_MB` | SteamCMD 子容器 memory+swap 合计上限（MiB），预设中与内存上限同值，禁用 swap |
| `BSP_DST_CONTAINER_MEMORY_MB` | 每个 DST 分片硬限（MiB），0 或未设置表示不限；实例设置可分别覆盖两片 |
| `BSP_HOST_STEAMCMD_PLANNING_MB` | 安装 / 更新前的内存规划预留（MiB），参与守卫判断 |
| `BSP_HOST_DST_PLANNING_MB` | DST 启动守卫的单分片规划下界（MiB）；与 Mod 估算取较大值，不被硬限截断 |
| `BSP_HOST_MEMORY_HEADROOM_MB` | 安装/启动守卫保留空闲（默认 512） |
| `BSP_HOST_MIN_AVAILABLE_MB` | 设为 `0` 可关闭守卫（小内存慎用） |
| `BSP_SWAP_ON_INSTALL` | 安装器在小内存机上自动创建缓存区文件（默认 `1`，设 `0` 关闭；等同 `--no-swap`） |
| `BSP_SWAP_SIZE` | root 手动命令默认 `2G`；首装按档位为 `4G`、`3G`、`2G`，显式设置优先 |
| `BSP_SWAP_FILE` | root 命令创建的新 swapfile 路径（默认 `/swapfile-bsp`）；显式新路径允许追加，禁止覆盖已有文件 |
| `BSP_SHARD_READY_WAIT_SEC` | 每分片启动等待上限秒数（默认 300）；洞穴预算含加载和互联确认，实例设置可覆盖 |
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
- **实例控制**：显示排队、准备、主世界加载、洞穴加载、验证互联、就绪等阶段，以及已用时间、剩余预算和资源诊断。单世界、双世界使用同一启动任务，同节点排队，排队时间不计入分片等待预算。
- **启动反馈**：受理请求提示正在启动，完整就绪后提示成功。60 秒无有效加载进展时提示，120 秒显示资源诊断；静默本身不会提前终止任务，重复 IPC 警告不计作加载进展。
- **启动失败**：区分加载超时、洞穴互联、查询通道、OOM、Lua 错误及进程退出，保存最近报告后清理本轮分片。停止或重启会取消旧任务；面板重启后保留原始等待期限。
- **资源与启动设置**：显示运行中的实际限制和下一次启动配置，支持继承全局、应用推荐值、主世界与洞穴分别设置硬限，以及 300/600/900 秒或自定义等待。

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
