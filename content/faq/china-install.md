---
slug: "china-install"
title: "中国大陆服务器怎么安装？"
category: "安装"
keywords: ["国内","中国大陆","ghcr","waiting","TLS","代理"]
errorCodes: []
relatedDocs: ["docs/install-docker.md"]
order: 2
sourceRef: "dd39ea940d144c13cffd7cc6d528a860f3ae2fb2"
---

国内的问题集中在镜像下载：安装器拉的是 GHCR 镜像，而它的镜像层域名 `pkg-containers.githubusercontent.com` 国内基本不可达，直接跑常卡在 `net/http: TLS handshake timeout`。

安装命令本身就是体检加安装：**不需要额外先跑一次体检**。安装器会先判断发行版、架构、内存、根分区余量、Docker 状态、GHCR 与 Steam CDN 可达性、面板端口占用，把这份报告打到屏幕上（同时写进安装状态文件），确认没有阻塞项才继续装。

```bash
tag=v0.19.0
# gh-proxy 加速；不可用时换成 https://ghfast.top/ 前缀。
# 用 curl -o 指定带版本号的文件名：wget 遇到同名文件是另存为 .1，容易继续跑上一次的旧脚本
curl -fL --retry 3 -o "install-${tag}.sh" \
  "https://gh-proxy.com/https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/${tag}/scripts/install.linux.sh"

# 自证版本：这一步必须输出 ...:-v0.19.0}}，对不上就停下排查。
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

`--network cn` 之外的参数见[参数速查](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/reference.md#安装器参数)与[镜像与更新](https://github.com/PMAT77/bubble-shark-panel/blob/dd39ea940d144c13cffd7cc6d528a860f3ae2fb2/docs/reference.md#镜像与更新)。常用三个：

- `BSP_GITHUB_PROXY=https://gh-proxy.com/`：固定一个加速节点，不再按内置代理池回退；
- `BSP_IMAGE_MIRRORS=mirror.example.com`：改用你控制的镜像源；
- `BSP_FORCE_IMAGE_PULL=1`：本地已有同名镜像也强制重新拉取。

</details>

<details>
<summary>没看到 skipping pull 又在下载，或安装器报 Compose 插件缺失</summary>

**又去下载镜像**：脚本默认 tag 与本地镜像 tag 不一致。两边都要等于 `${tag}`：`grep '^BSP_RELEASE_TAG=' "install-${tag}.sh"` 与 `docker images | grep bubblesharkpanel`。也可以显式覆盖重跑：

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
