#!/usr/bin/env bash

set -Eeuo pipefail

# Accept legacy process settings without overriding an explicitly supplied BSP key.
for legacy_key in ${!GSH_@}; do
  brand_key="BSP_${legacy_key#GSH_}"
  if [[ ! -v "$brand_key" ]]; then
    printf -v "$brand_key" '%s' "${!legacy_key}"
    export "$brand_key"
  fi
done
unset legacy_key brand_key

# -----------------------------------------------------------------------------
# 安装脚本默认参数与运行时路径
# -----------------------------------------------------------------------------
# Preserve installed deployment identity and paths; never infer a target between two installations.
PANEL_INSTALL_DIR="${PANEL_INSTALL_DIR:-${BSP_INSTALL_DIR:-${BSP_STACK_DIR:-}}}"
LEGACY_DEPLOYMENT=0
if [[ -z "${PANEL_INSTALL_DIR:-}" ]]; then
  if [[ -f /opt/game-server-hub/panel.env && -f /opt/bubblesharkpanel/panel.env ]]; then
    printf '%s\n' 'Both installations exist; set PANEL_INSTALL_DIR explicitly.' >&2
    exit 1
  fi
  if [[ -f /opt/game-server-hub/panel.env ]]; then PANEL_INSTALL_DIR=/opt/game-server-hub; fi
fi
if [[ -f "${PANEL_INSTALL_DIR:-/opt/bubblesharkpanel}/panel.env" ]]; then
  existing_env="${PANEL_INSTALL_DIR:-/opt/bubblesharkpanel}/panel.env"
  if grep -Eq '^(GSH_|DB_PATH=.*game-server-hub)' "$existing_env"; then LEGACY_DEPLOYMENT=1; fi
  # Read values as data, never source user-owned panel.env as root.
  while IFS= read -r existing_line; do
    if [[ "$existing_line" =~ ^(BSP_|GSH_)[A-Z0-9_]+= ]]; then
      existing_key="${existing_line%%=*}"
      brand_key="BSP_${existing_key#*_}"
      # Process settings win; prefer BSP in the file regardless of line order.
      if [[ ! -v "$brand_key" ]]; then
        canonical_line="$(grep -E "^${brand_key}=" "$existing_env" | tail -n 1 || true)"
        existing_value="${canonical_line:-$existing_line}"
        printf -v "$brand_key" '%s' "${existing_value#*=}"
        export "$brand_key"
      fi
    fi
  done < "$existing_env"
  for existing_key in PANEL_DATA_DIR PANEL_LOG_DIR PANEL_INSTANCES_DIR PANEL_BACKUPS_DIR DB_PATH; do
    existing_value="$(grep -E "^${existing_key}=" "$existing_env" | tail -n 1 || true)"
    if [[ ! -v "$existing_key" && -n "$existing_value" ]]; then printf -v "$existing_key" '%s' "${existing_value#*=}"; export "$existing_key"; fi
  done
fi
if [[ -n "${DB_PATH:-}" && "$DB_PATH" == /* && "$DB_PATH" != /app/* && -z "${PANEL_DATA_DIR:-}" ]]; then PANEL_DATA_DIR="$(dirname "$DB_PATH")"; fi
if [[ "$LEGACY_DEPLOYMENT" == 1 ]]; then
  PANEL_DATA_DIR="${PANEL_DATA_DIR:-/var/lib/game-server-hub}"
  PANEL_LOG_DIR="${PANEL_LOG_DIR:-/var/log/game-server-hub}"
  BSP_NATIVE_USER="${BSP_NATIVE_USER:-gsh}"
  BSP_NATIVE_GROUP="${BSP_NATIVE_GROUP:-gsh}"
  BSP_NATIVE_SERVICE="${BSP_NATIVE_SERVICE:-game-server-hub.service}"
  BSP_NATIVE_UPDATE_SERVICE="${BSP_NATIVE_UPDATE_SERVICE:-game-server-hub-update.service}"
  BSP_NATIVE_UPDATE_PATH="${BSP_NATIVE_UPDATE_PATH:-game-server-hub-update.path}"
  BSP_NATIVE_UPDATE_HELPER="${BSP_NATIVE_UPDATE_HELPER:-/usr/local/lib/game-server-hub/gsh-native-update}"
  BSP_PANEL_CONTAINER_NAME="${BSP_PANEL_CONTAINER_NAME:-game-server-hub-panel}"
  BSP_SWAP_FILE="${BSP_SWAP_FILE:-/swapfile-gsh}"
  BSP_RESOURCE_PREFIX="${BSP_RESOURCE_PREFIX:-gsh}"
  DB_PATH="${DB_PATH:-${PANEL_DATA_DIR}/game-server-hub.sqlite}"
fi
if [[ -n "${DB_PATH:-}" && "$DB_PATH" == /* && "$DB_PATH" != /app/* && -z "${PANEL_DATA_DIR:-}" ]]; then PANEL_DATA_DIR="$(dirname "$DB_PATH")"; fi
PANEL_DB_FILENAME="${DB_PATH:-}"
PANEL_DB_FILENAME="${PANEL_DB_FILENAME##*/}"
PANEL_DB_FILENAME="${PANEL_DB_FILENAME:-bubblesharkpanel.sqlite}"
PANEL_NATIVE_SERVICE="${BSP_NATIVE_SERVICE:-bubblesharkpanel.service}"

SCRIPT_NAME="$(basename "$0")" # 当前脚本名称（用于日志展示）。
BSP_RELEASE_TAG="${BSP_RELEASE_TAG:-${PANEL_IMAGE_TAG:-v0.17.0}}" # 默认安装的不可变 Release；同时锁定安装资源与镜像版本。
INSTALLER_REPO_RAW="${INSTALLER_REPO_RAW:-}" # 兼容旧变量：指定单一安装资源源（为空时使用 INSTALLER_REPO_MIRRORS）。
# GitHub 资源加速代理（前缀拼接型）：安装资源与 Native 包共用；BSP_GITHUB_PROXY 可强制指定单一节点。
GITHUB_PROXY_SITES="${GITHUB_PROXY_SITES:-https://gh-proxy.com/,https://ghfast.top/,https://ghproxy.com/}"
BSP_GITHUB_PROXY="${BSP_GITHUB_PROXY:-}" # 强制指定 GitHub 加速代理（如 https://gh-proxy.com/）；为空则走镜像池自动回退。
INSTALLER_REPO_MIRRORS="${INSTALLER_REPO_MIRRORS:-}" # 安装资源镜像池；为空时由 init_installer_repo_pool 按代理清单生成。
# 校验对象是镜像源提供的 git blob 原始字节（LF）；改动 compose 后必须同步更新此处。
# 历史 pin eb30aeae... 与 v0.1.4 tag 内 compose blob（a34665e2...）不匹配，导致严格校验必然失败。
INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_YML="${INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_YML:-8385b636f58e76cdb9eb2e6cf7649c43ae5eea502eefe7380b42423e037a1458}"
INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_BIND_YML="${INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_BIND_YML:-2ca65c80ee02cfb08e3aec26ae17dabb38296e825147a43896bc7daf1cb07d65}"
# Debian 12 等发行版源不含 Compose v2 时，从 docker/compose GitHub Release 自动补装 CLI 插件。
# 摘要与官方 .sha256 / checksums.txt 资产双源核对；升级插件版本时需同步替换版本号与两个摘要。
COMPOSE_PLUGIN_VERSION="v2.39.2"
COMPOSE_PLUGIN_SHA256_X86_64="a55a8cd4ef103aac282812554e531aac8df7e914a287ee81e14d695556a22902"
COMPOSE_PLUGIN_SHA256_AARCH64="54488fffb60782f3c8787a48b95ed15f49f5a3a85f4105304bd46db5edd9db61"
COMPOSE_PLUGIN_INSTALL_PATH="/usr/local/lib/docker/cli-plugins/docker-compose"
COMPOSE_PLUGIN_MAX_TIME_SECONDS="${COMPOSE_PLUGIN_MAX_TIME_SECONDS:-1800}"
INSTALL_MODE="${BSP_INSTALL_MODE:-auto}" # auto | docker | native
NETWORK_PROFILE="${BSP_NETWORK_PROFILE:-auto}" # auto | cn | global
RESOLVED_INSTALL_MODE=""
RESOLVED_NETWORK_PROFILE=""
MIN_FREE_DISK_MB=4096 # 最小可用磁盘空间阈值（MB）。
HOST_MEMORY_WARN_MIN_MB=3800 # 总内存低于此值（约 4GiB）时输出 WARN。
HOST_MEMORY_TIER_SMALL_MAX_MB=5120 # < 此值视为 small 预设。
HOST_MEMORY_TIER_MEDIUM_MAX_MB=8192 # < 此值视为 medium 预设。
BSP_PANEL_ENV_PRESET="${BSP_PANEL_ENV_PRESET:-auto}" # auto | small | medium | large | none
# 小内存机安装时自动创建缓存区文件（1=开启，默认）。面板容器不以 root 运行，创建缓存区需要 root，
# 所以留给用户的不该是「装完再自己 SSH 执行一次」，而是在这里做掉；--no-swap 或 BSP_SWAP_ON_INSTALL=0 关闭。
BSP_SWAP_ON_INSTALL="${BSP_SWAP_ON_INSTALL:-1}"
# 自动创建 swap 的总内存阈值（MiB），与 HOST_MEMORY_TIER_SMALL_MAX_MB 同档：< 5 GiB 视为小内存机。
BSP_SWAP_AUTO_THRESHOLD_MB="${BSP_SWAP_AUTO_THRESHOLD_MB:-${HOST_MEMORY_TIER_SMALL_MAX_MB}}"
# 自动创建 swap 的结果（供 print_summary 分支）：none | active | created | skipped | failed
AUTO_SWAP_STATE="none"
AUTO_SWAP_TARGET_MB=0
AUTO_SWAP_SKIPPED_REASON=""
RETRY_MAX=3 # 可重试操作的最大重试次数。
RETRY_DELAY_SECONDS=3 # 每次重试之间的等待秒数。
REPO_DOWNLOAD_MAX_ATTEMPTS="${REPO_DOWNLOAD_MAX_ATTEMPTS:-2}" # 每个安装资源源最大下载重试次数。
REPO_DOWNLOAD_TIMEOUT_SECONDS="${REPO_DOWNLOAD_TIMEOUT_SECONDS:-45}" # 安装资源单次下载超时时间（秒）。
REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS="${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS:-10}" # 安装资源连接超时时间（秒）。
OPEN_PANEL_PORT=0 # 是否在安装时开放面板 TCP 端口。
OPEN_DST_PORTS=0 # 是否在安装时开放 DST 默认 UDP 游戏端口。
GHCR_CHECK_TIMEOUT_SECONDS="${GHCR_CHECK_TIMEOUT_SECONDS:-20}" # ghcr.io 连通性预检查超时时间（秒）。
STRICT_GHCR_CHECK="${STRICT_GHCR_CHECK:-0}" # 是否要求 ghcr.io 预检查必须通过（1=失败即终止，0=失败仅告警）。
DOCKER_REPO_CHECK_TIMEOUT_SECONDS="${DOCKER_REPO_CHECK_TIMEOUT_SECONDS:-8}" # download.docker.com 连通性预检查超时时间（秒）。
STRICT_DOCKER_REPO_CHECK="${STRICT_DOCKER_REPO_CHECK:-0}" # 是否要求 download.docker.com 预检查必须通过（1=失败即终止，0=失败仅告警）。
USE_CN_DEBIAN_MIRROR="${USE_CN_DEBIAN_MIRROR:-0}" # Debian 是否优先尝试国内镜像（1=启用，0=关闭）。
DEBIAN_MIRROR_URL="${DEBIAN_MIRROR_URL:-https://mirrors.tuna.tsinghua.edu.cn/debian}" # Debian 主仓库镜像。
DEBIAN_SECURITY_MIRROR_URL="${DEBIAN_SECURITY_MIRROR_URL:-https://mirrors.tuna.tsinghua.edu.cn/debian-security}" # Debian 安全仓库镜像。
UBUNTU_MIRROR_URL="${UBUNTU_MIRROR_URL:-https://mirrors.tuna.tsinghua.edu.cn/ubuntu}" # Ubuntu 主仓库与安全更新镜像。
APT_SOURCES_BACKUP_DIR="/tmp/bsp-apt-sources-backup"

# DST 默认 UDP 端口（与 cluster.ini / server.ini 默认值一致）
DST_GAME_PORT="${DST_GAME_PORT:-10999}"
DST_AUTH_PORT="${DST_AUTH_PORT:-8766}"
DST_MASTER_PORT="${DST_MASTER_PORT:-12346}"
# 洞穴分片端口（默认 = 主世界 +1 / +2，与 server-ini.ts 的 defaultCavesServerIniFields 一致）
DST_CAVES_GAME_PORT="${DST_CAVES_GAME_PORT:-11000}"
DST_CAVES_AUTH_PORT="${DST_CAVES_AUTH_PORT:-8768}"
DST_CAVES_MASTER_PORT="${DST_CAVES_MASTER_PORT:-12348}"

PANEL_NAME="${PANEL_NAME:-bubblesharkpanel}" # 面板逻辑名称（可被环境变量覆盖）。
PANEL_PORT="${PANEL_PORT:-9527}" # 面板对外暴露端口（默认使用高位端口以降低备案拦截影响）。
PANEL_PROTOCOL="${PANEL_PROTOCOL:-http}" # 访问协议（用于生成访问 URL）。
INSTALL_STEAMCMD_IMAGE="${INSTALL_STEAMCMD_IMAGE:-1}" # 安装阶段是否预拉 SteamCMD 镜像（默认拉取，安装完成后可直接创建实例）。
# v0.2.0 起三镜像合一：面板/DST/SteamCMD 共用同一统一镜像引用（仅 GHCR 官方源；
# 国内拉取失败时优先使用 Release 离线镜像包，或在 panel.env 配置 BSP_IMAGE_MIRRORS 自选镜像代理）。
PANEL_IMAGE_OVERRIDE="${PANEL_IMAGE:-}" # 完整面板镜像引用；设置后直接采用（不再拼接 GHCR 引用）。
PANEL_INSTALL_DIR="${PANEL_INSTALL_DIR:-/opt/bubblesharkpanel}" # 安装目录（放置 env/compose）。
PANEL_DATA_DIR="${PANEL_DATA_DIR:-/var/lib/bubblesharkpanel}" # 面板持久化数据目录。
PANEL_LOG_DIR="${PANEL_LOG_DIR:-/var/log/bubblesharkpanel}" # 面板日志与安装状态目录。
if [[ "${BSP_RUNTIME_MODE:-}" == native ]]; then
  PANEL_INSTANCES_DIR="${PANEL_INSTANCES_DIR:-${BSP_INSTANCES_ROOT:-}}"
  PANEL_BACKUPS_DIR="${PANEL_BACKUPS_DIR:-${BSP_BACKUPS_ROOT:-}}"
fi
PANEL_INSTANCES_DIR="${PANEL_INSTANCES_DIR:-${PANEL_DATA_DIR}/instances}" # 游戏实例数据目录。
PANEL_BACKUPS_DIR="${PANEL_BACKUPS_DIR:-${PANEL_DATA_DIR}/backups}" # 备份目录。
PANEL_BIND_COMPOSE_FILE="${PANEL_INSTALL_DIR}/docker-compose.bind.yml"
PANEL_IMAGE_TAG="${PANEL_IMAGE_TAG:-${BSP_RELEASE_TAG}}" # 容器镜像标签；默认与安装资源锁定同一个 Release。
# v0.2.0 三键同值（统一镜像）；完整引用由 finalize_image_refs 按 registry 生成，panel.env 保留三个变量以兼容面板配置读取与历史脚本。
PANEL_IMAGE="" # 统一镜像完整引用（由 finalize_image_refs 填充；PANEL_IMAGE_OVERRIDE 设置时直接采用）。
BSP_GAME_DST_IMAGE=""
BSP_STEAMCMD_IMAGE=""
INSTALL_STEAMCMD_PULL_IMAGE=""
PANEL_ENV_FILE="${PANEL_INSTALL_DIR}/panel.env" # 运行时环境变量文件路径。
PANEL_COMPOSE_FILE="${PANEL_INSTALL_DIR}/docker-compose.yml" # Docker Compose 文件路径。
STATUS_FILE="${PANEL_LOG_DIR}/install.status" # 安装状态追踪文件路径。
DIAGNOSTICS_FILE="${PANEL_LOG_DIR}/install.diagnostics.log" # 失败时生成的脱敏诊断报告。
PANEL_HEALTHCHECK_TIMEOUT_SECONDS="${PANEL_HEALTHCHECK_TIMEOUT_SECONDS:-90}" # 启动后健康检查总超时。
PANEL_HEALTHCHECK_INTERVAL_SECONDS="${PANEL_HEALTHCHECK_INTERVAL_SECONDS:-3}" # 健康检查轮询间隔。
NATIVE_SERVICE_USER="${BSP_NATIVE_USER:-bsp}"
NATIVE_SERVICE_GROUP="${BSP_NATIVE_GROUP:-bsp}"
NATIVE_USER_HOME="${BSP_NATIVE_USER_HOME:-${PANEL_DATA_DIR}/home}"
NATIVE_RELEASE_ROOT="${BSP_NATIVE_RELEASE_ROOT:-${PANEL_INSTALL_DIR}/releases}"
NATIVE_CURRENT_LINK="${PANEL_INSTALL_DIR}/current"
NATIVE_RELEASE_NAME="bubblesharkpanel-native-${BSP_RELEASE_TAG}-linux-x64"
NATIVE_RELEASE_ARCHIVE="${BSP_NATIVE_RELEASE_ARCHIVE:-}"
NATIVE_RELEASE_MIRRORS="${BSP_NATIVE_RELEASE_MIRRORS:-}" # 为空时由 init_installer_repo_pool 生成（直连 + 加速代理）。https://github.com/PMAT77/bubble-shark-panel/releases/download/${BSP_RELEASE_TAG},https://ghproxy.com/https://github.com/PMAT77/bubble-shark-panel/releases/download/${BSP_RELEASE_TAG}}"
NATIVE_STEAMCMD_DIR="${BSP_NATIVE_STEAMCMD_DIR:-${PANEL_INSTALL_DIR}/runtime/steamcmd}"
NATIVE_STEAMCMD_PATH="${BSP_NATIVE_STEAMCMD_PATH:-${NATIVE_STEAMCMD_DIR}/steamcmd.sh}"
NATIVE_STEAMCMD_URL="${BSP_NATIVE_STEAMCMD_URL:-https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz}"
NATIVE_SYSTEMD_UNIT="/etc/systemd/system/${PANEL_NATIVE_SERVICE}"
# Native 面板内更新：面板（非特权用户）只在 NATIVE_UPDATE_DIR 写请求文件，
# 由 root 侧 oneshot 服务执行真正的安装动作（见 scripts/bsp-native-update.sh）。
NATIVE_UPDATE_DIR="${BSP_NATIVE_UPDATE_DIR:-${PANEL_DATA_DIR}/panel-update}"
NATIVE_UPDATE_HELPER_PATH="${BSP_NATIVE_UPDATE_HELPER:-/usr/local/lib/bubblesharkpanel/bsp-native-update}"
NATIVE_UPDATE_SERVICE="${BSP_NATIVE_UPDATE_SERVICE:-bubblesharkpanel-update.service}"
NATIVE_UPDATE_PATH_UNIT="${BSP_NATIVE_UPDATE_PATH:-bubblesharkpanel-update.path}"
NATIVE_UPDATE_SERVICE_UNIT="/etc/systemd/system/${NATIVE_UPDATE_SERVICE}"
NATIVE_UPDATE_PATH_UNIT_FILE="/etc/systemd/system/${NATIVE_UPDATE_PATH_UNIT}"
NATIVE_RELEASE_REPLACED=0
NATIVE_PREVIOUS_RELEASE=""
UPGRADE_STATE_BACKUP_DIR=""
UPGRADE_DATABASE_BACKUP=""

DISTRO_ID="" # 发行版 ID（如 ubuntu/debian）。
DISTRO_CODENAME="" # 发行版代号（如 jammy/bookworm）。
PANEL_HOST="${PANEL_HOST:-}" # 面板访问主机地址（显式指定时直接用；为空时按默认路由出口自动探测）。
PANEL_HOST_SOURCE="" # 本机地址来源：user=环境变量显式指定；interface=自动探测。
PANEL_PUBLIC_URL_OVERRIDE="${PANEL_PUBLIC_URL:-}" # 显式指定的对外访问 URL；设置后跳过一切自动探测。
PANEL_ACCESS_URL="" # 最终写入 panel.env 的对外访问 URL（PANEL_PUBLIC_URL）。
PANEL_LAN_URL="" # 本机地址对应的访问 URL（只在内网可达，摘要中与对外地址并列展示）。
PANEL_PUBLIC_IP_SOURCE="" # 对外地址来源：user|interface|cloud_metadata|ip_echo|lan。
PANEL_DETECTED_PUBLIC_IP="" # 自动探测到的对外 IPv4。
BSP_PANEL_AUTO_PUBLIC_IP="${BSP_PANEL_AUTO_PUBLIC_IP:-1}" # 是否允许探测对外 IP（0/false/off/no 关闭）。
BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS="${BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS:-3}" # 对外地址探测的总耗时预算（秒）。
# 探测源与 server 侧 server/src/infra/game-adapter/dst/connect-host.ts 保持一致：
# 云平台元数据可信度最高（云厂商的公网 IP 必然映射到本机），出站回显拿到的可能只是出口地址。
# GCP/Azure 的元数据端点需要额外请求头，这里不纳入；那类环境用 PANEL_PUBLIC_URL 显式指定。
PANEL_CLOUD_METADATA_URLS=(
  "http://169.254.169.254/latest/meta-data/public-ipv4"
  "http://100.100.100.200/latest/meta-data/eipv4"
  "http://100.100.100.200/latest/meta-data/public-ipv4"
  "http://metadata.tencentyun.com/latest/meta-data/public-ipv4"
  "http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address"
)
PANEL_PUBLIC_IP_ECHO_URLS=(
  "https://api.ipify.org?format=text"
  "https://ifconfig.me/ip"
  "https://icanhazip.com"
)
ADMIN_USERNAME="${ADMIN_USERNAME:-superadmin}" # 初始管理员用户名。
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}" # 初始管理员密码（为空时自动生成随机密码）。
HIDE_ADMIN_PASSWORD="${HIDE_ADMIN_PASSWORD:-0}" # 设 1 时不在安装摘要里打印初始密码（无人值守安装把输出重定向到文件时用）。
ROLLBACK_ENABLED=0 # 是否允许回滚（部署开始后置为 1）。
INSTALL_COMPLETED=0
CURRENT_STAGE="bootstrap"
LAST_ERROR_LINE="unknown"
LAST_ERROR_EXIT_CODE=1
LAST_ERROR_MESSAGE="Unexpected installer failure"
INSTALLER_REPO_POOL_INITIALIZED=0
declare -a INSTALLER_REPO_POOL=()
STRICT_INSTALLER_ASSET_CHECKSUM="${STRICT_INSTALLER_ASSET_CHECKSUM:-1}" # 安装资源校验是否强制（1=校验失败即中止，0=仅告警）。
CHECK_ONLY=0 # --check：只打印前置体检报告后退出，不改动系统（不建目录、不写状态文件、不装依赖）。
CHECK_REPORT_FILE="${CHECK_REPORT_FILE:-}" # 体检报告落盘路径（仅 --check 生效；为空则只打印到终端）。
# 前置体检的探测结论：在体检阶段算一次，安装阶段直接复用，避免同一机器上重复探测。
GHCR_REACHABLE=0
GHCR_LAYER_ACCESSIBLE=0 # GHCR 的层数据是否真的拉得动（元数据可达 ≠ 层可达）。
GHCR_LAYER_PROBE_SECONDS=-1 # 层数据探测耗时（秒）；-1 表示没测出来。
DOCKER_REPO_REACHABLE=0
SYSTEMCTL_AVAILABLE=0
STEAM_CDN_REACHABLE=0
HOST_IPV4=""
# 镜像获取偏好：auto（按网络档决定）| offline（强制 Release 离线包）| native（强制 GHCR 直拉）。
BSP_IMAGE_SOURCE="${BSP_IMAGE_SOURCE:-auto}"
GHCR_LAYER_PROBE_MAX_SECONDS="${GHCR_LAYER_PROBE_MAX_SECONDS:-20}" # 层数据探测单次请求上限（秒）。
DOCKER_PULL_STALL_SECONDS="${DOCKER_PULL_STALL_SECONDS:-90}" # 直拉时多久没有进度就判定停滞（秒）。
RELEASE_OFFLINE_IMAGE_PATH="" # Release 离线镜像包落盘路径（自动兜底或手动指定时设置）。
OFFLINE_IMAGE_IMPORTED=0 # 离线镜像包是否已导入本地 Docker。
IMAGE_ROUTE="" # 镜像获取路线：ghcr | offline | offline-present | custom。
OFFLINE_IMAGE_ROUTE=0 # 是否需要在安装阶段自动下载并导入 Release 离线镜像包。
PREFLIGHT_FAILURES=0 # 体检中「不通过」的条目数（>0 时安装中止）。
PREFLIGHT_WARNINGS=0 # 体检中「警告」的条目数（只提示，不中止）。
PREFLIGHT_NEXT_STEP="" # 体检给出的第一步建议；失败时由收尾逻辑打印出来。
PREFLIGHT_REPORT_LINES=() # 体检报告的每一行；安装模式下整段追加到状态文件。
INSTALL_STARTED_AT=0 # 体检通过时的 epoch 秒，用于摘要里的安装耗时。
# 离线镜像包约 227 MB，远大于安装资源；单次下载上限必须单独放宽，否则弱网下会被 45 秒掐断。
OFFLINE_IMAGE_MAX_TIME_SECONDS="${OFFLINE_IMAGE_MAX_TIME_SECONDS:-1800}"

# 基础日志函数，统一输出格式。
log_info() {
  printf '[INFO] %s\n' "$*"
}

# 警告日志输出到标准错误。
log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

# 错误日志输出到标准错误。
log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# 输出错误并立即退出脚本。
abort() {
  LAST_ERROR_MESSAGE="$*"
  LAST_ERROR_LINE="${BASH_LINENO[0]:-unknown}"
  log_error "$*"
  exit 1
}

# -----------------------------------------------------------------------------
# 前置探测：体检与网络路线判定共用，所以放在日志函数之后、业务函数之前。
# -----------------------------------------------------------------------------
probe_https_url() {
  local url="$1"
  local timeout_seconds="${2:-6}"
  curl -fsSL -o /dev/null --connect-timeout 3 --max-time "${timeout_seconds}" "${url}" >/dev/null 2>&1
}

# registry 连通性预检：探测 registry v2 端点（200/401/403 视为可达），避免 HEAD / 405 误报。
check_registry_reachability() {
  local registry="${1:-ghcr.io}"
  local status_code

  status_code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" --max-time "${GHCR_CHECK_TIMEOUT_SECONDS}" "https://${registry}/v2/")" || return 1
  case "${status_code}" in
    200|401|403|404|405|30[0-9])
      log_info "Registry preflight check passed via https://${registry}/v2/ (HTTP ${status_code})."
      return 0
      ;;
    *)
      log_warn "Registry preflight returned HTTP ${status_code} on https://${registry}/v2/."
      return 1
      ;;
  esac
}

# 本机出口 IPv4；取不到时留空（诊断信息，缺失不影响判定）。
resolve_host_ipv4() {
  local source_ip
  source_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
  printf '%s' "${source_ip}"
}

# 探测 GHCR 的「层数据」是否真的拉得动。
#
# registry 元数据可达（/v2/ 返回 401）不代表层数据可达：层数据在 pkg-containers.githubusercontent.com
# 上，国内常表现为元数据正常、层下载挂住。此前预检只看元数据，于是被判定「可达」走了直拉，
# 用户卡在 Waiting 上无限等待。这里取一次匿名 token 并真拉一个小 blob（镜像配置，几百字节），
# 实测通过才算层数据可用；整段有硬超时，慢的就是不可用。
probe_ghcr_layer_access() {
  GHCR_LAYER_ACCESSIBLE=0
  GHCR_LAYER_PROBE_SECONDS=-1

  local repository="pmat77/bubblesharkpanel" token digest started elapsed
  local max_seconds="${GHCR_LAYER_PROBE_MAX_SECONDS}"
  local manifest_url="https://ghcr.io/v2/${repository}/manifests/${PANEL_IMAGE_TAG}"
  local accept='Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'

  token="$(curl -fsSL --connect-timeout 5 --max-time "${max_seconds}" \
    "https://ghcr.io/token?scope=repository:${repository}:pull&service=ghcr.io" 2>/dev/null \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')" || {
    log_warn "GHCR token 探测失败（退出码 $?），按不可达处理。"
    return 0
  }
  if [[ -z "${token}" ]]; then
    return 0
  fi

  digest="$(curl -fsSL --connect-timeout 5 --max-time "${max_seconds}" \
    -H "Authorization: Bearer ${token}" -H "${accept}" "${manifest_url}" 2>/dev/null \
    | tr ',' '\n' | sed -n 's/.*"digest":"\(sha256:[0-9a-f]*\)".*/\1/p' | head -1)" || {
    log_warn "GHCR manifest 探测失败（退出码 $?），按不可达处理。"
    return 0
  }
  if [[ -z "${digest}" ]]; then
    return 0
  fi

  started="$(date +%s)"
  if curl -fsS --connect-timeout 5 --max-time "${max_seconds}" \
    -H "Authorization: Bearer ${token}" -o /dev/null \
    "https://ghcr.io/v2/${repository}/blobs/${digest}" 2>/dev/null; then
    elapsed=$(( $(date +%s) - started ))
    GHCR_LAYER_PROBE_SECONDS="${elapsed}"
    if (( elapsed <= max_seconds )); then
      GHCR_LAYER_ACCESSIBLE=1
    fi
  else
    log_warn "GHCR blob 探测失败（退出码 $?），按不可达处理。"
  fi
  return 0
}

# 探测每项独立超时并各自打点：弱网下最坏耗时 = 各项超时之和 * 站点数，不能无限等。
probe_reachability() {
  GHCR_REACHABLE=0
  GHCR_LAYER_ACCESSIBLE=0
  GHCR_LAYER_PROBE_SECONDS=-1
  DOCKER_REPO_REACHABLE=0
  STEAM_CDN_REACHABLE=0
  SYSTEMCTL_AVAILABLE=0
  HOST_IPV4="$(resolve_host_ipv4)"

  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    if [[ -z "${PANEL_IMAGE_OVERRIDE}" ]]; then
      if check_registry_reachability "ghcr.io" >/dev/null 2>&1; then
        GHCR_REACHABLE=1
        # 元数据可达才值得再花时间测层数据：探不通就没必要测。
        probe_ghcr_layer_access
      fi
    fi

    local docker_repo_status
    docker_repo_status="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" --max-time "${DOCKER_REPO_CHECK_TIMEOUT_SECONDS}" "https://download.docker.com/linux/" 2>/dev/null || true)"
    case "${docker_repo_status}" in
      200|30[0-9])
        DOCKER_REPO_REACHABLE=1
        ;;
      *)
        # 解析命令缺失时也走这里：宁可报「不可达」由上层提示回退，也不要让用户以为预检过了。
        if [[ "${docker_repo_status}" != "" ]]; then
          log_warn "Docker 官方源预检未通过（HTTP ${docker_repo_status}）：将回退到发行版自带的 docker.io 包。"
        fi
        ;;
    esac
  fi

  if command -v systemctl >/dev/null 2>&1; then
    SYSTEMCTL_AVAILABLE=1
  fi

  # 游戏本体与 Mod 走 Steam CDN，此前完全没有探测点：国内不可达时故障要等玩家进服才暴露。
  local steam_ok=0
  if probe_https_url "https://steamcdn-a.akamaihd.net/" 8 || probe_https_url "https://steamcommunity.com/" 8; then
    steam_ok=1
  fi
  if [[ "${steam_ok}" -eq 1 ]]; then
    STEAM_CDN_REACHABLE=1
  fi
}

# 判定这次安装该走哪条镜像路线。
#
# 三条路线：custom（用户指定引用）| ghcr（直拉）| offline（Release 离线镜像包）。
# 离线包优先于直拉的两个理由：它走加速代理池（国内比 GHCR 的层域名可靠），且带 .sha256 校验、
# 失败能立刻判定；直拉在国外更快，所以海外档仍默认直拉。OFFLINE_IMAGE_ROUTE=1 表示
# 安装阶段要去下载并导入离线包，失败时由 ensure_panel_image_available 降级成直拉。
resolve_image_route() {
  OFFLINE_IMAGE_ROUTE=0
  IMAGE_ROUTE=""
  if [[ "${RESOLVED_INSTALL_MODE}" != "docker" ]]; then
    return
  fi
  if [[ -n "${PANEL_IMAGE_OVERRIDE}" ]]; then
    IMAGE_ROUTE="custom"
    return
  fi
  # 本地已有目标镜像：后面会跳过拉取，路线无关紧要。
  if [[ "${BSP_FORCE_IMAGE_PULL:-0}" != "1" ]] \
    && run_as_root docker image inspect "${PANEL_IMAGE}" >/dev/null 2>&1; then
    IMAGE_ROUTE="offline-present"
    return
  fi

  local prefer
  case "${BSP_IMAGE_SOURCE}" in
    offline)
      prefer="offline"
      ;;
    native)
      prefer="ghcr"
      ;;
    auto)
      # 国内档默认离线包；层数据实测不可达时也走离线包（元数据可达不代表拉得动）。
      if [[ "${RESOLVED_NETWORK_PROFILE}" == "cn" || "${GHCR_LAYER_ACCESSIBLE}" -ne 1 ]]; then
        prefer="offline"
      else
        prefer="ghcr"
      fi
      ;;
    *)
      abort "Invalid BSP_IMAGE_SOURCE '${BSP_IMAGE_SOURCE}'. Expected auto, offline or native."
      ;;
  esac

  # GHCR 连元数据都拿不到时不必先试直拉。
  if [[ "${prefer}" == "ghcr" && "${GHCR_REACHABLE}" -ne 1 ]]; then
    prefer="offline"
  fi

  if [[ "${prefer}" == "offline" ]]; then
    IMAGE_ROUTE="offline"
    OFFLINE_IMAGE_ROUTE=1
  else
    IMAGE_ROUTE="ghcr"
  fi
}

# 以 root 执行命令；若非 root 则自动走 sudo。
run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    abort "sudo is required. Please rerun as root or install sudo first."
  fi

  sudo "$@"
}

try_as_root() {
  if [[ "${BSP_DIAGNOSTICS_UNPRIVILEGED:-0}" == "1" ]]; then
    "$@"
  elif [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

# 只读取精确的 KEY=value 行，不 source 用户可编辑的 panel.env。
read_env_value() {
  local file="$1"
  local key="$2"
  local legacy_key="${key/BSP_/GSH_}"
  local command=(awk -v "target=${key}" -v "legacy=${legacy_key}" '
    index($0, legacy "=") == 1 && !found { value = substr($0, length(legacy) + 2) }
    index($0, target "=") == 1 { found = 1;
      value = substr($0, length(target) + 2)
    }
    END {
      sub(/\r$/, "", value)
      printf "%s", value
    }
  ' "${file}")
  if [[ -r "${file}" ]]; then
    "${command[@]}"
  else
    try_as_root "${command[@]}"
  fi
}

# 仅当键不存在时追加，不覆盖已有值。
# 用于升级路径补齐必需键：老 panel.env 可能缺 PANEL_DATA_DIR / PANEL_LOG_DIR / PANEL_PORT 等，
# 而 docker-compose.bind.yml 依赖它们；upsert 会覆盖用户自定义值，故单列一个"仅缺失才补"的函数。
ensure_env_values() {
  local env_file="$1"
  shift
  local pair key
  for pair in "$@"; do
    key="${pair%%=*}"
    if [[ -z "$(read_env_value "${env_file}" "${key}")" ]]; then
      printf '%s\n' "${pair}" | run_as_root tee -a "${env_file}" >/dev/null
      log_info "Added missing key to panel.env: ${key}"
    fi
  done
}

# 原子更新指定环境变量，保留未涉及的用户配置、权限和文件 inode。
upsert_env_values() {
  local file="$1"
  shift
  local updater
  updater='
    set -Eeuo pipefail
    file="$1"
    shift
    work="$(mktemp)"
    cp "$file" "$work"
    for pair in "$@"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      next="$(mktemp)"
      awk -v target="$key" -v replacement="$key=$value" "
        BEGIN { replaced = 0 }
        index(\$0, target \"=\") == 1 {
          if (!replaced) {
            print replacement
            replaced = 1
          }
          next
        }
        { print }
        END {
          if (!replaced) {
            print replacement
          }
        }
      " "$work" > "$next"
      mv "$next" "$work"
    done
    cat "$work" > "$file"
    rm -f "$work"
  '
  if [[ -w "${file}" ]]; then
    bash -c "${updater}" _ "${file}" "$@"
  else
    run_as_root bash -c "${updater}" _ "${file}" "$@"
  fi
}

resolve_existing_install_mode() {
  if ! try_as_root test -f "${PANEL_ENV_FILE}"; then
    return 1
  fi
  local existing_mode
  existing_mode="$(read_env_value "${PANEL_ENV_FILE}" "BSP_RUNTIME_MODE")"
  printf '%s' "${existing_mode:-docker}"
}

validate_install_mode_transition() {
  local existing_mode
  if ! existing_mode="$(resolve_existing_install_mode)"; then
    return
  fi
  if [[ "${existing_mode}" != "${RESOLVED_INSTALL_MODE}" ]]; then
    abort "Existing ${existing_mode} installation detected at ${PANEL_INSTALL_DIR}. Automatic cross-mode migration is not supported; back up data first. See docs/install-docker.md or docs/install-native.md."
  fi
  log_info "Existing ${existing_mode} installation detected; performing an in-place upgrade."
}

backup_existing_install_state() {
  local existing_mode timestamp database_path
  if ! existing_mode="$(resolve_existing_install_mode)" || [[ "${existing_mode}" != "${RESOLVED_INSTALL_MODE}" ]]; then
    return
  fi

  timestamp="$(date +%Y%m%d%H%M%S)"
  UPGRADE_STATE_BACKUP_DIR="${PANEL_BACKUPS_DIR}/panel-upgrades/${timestamp}-${BSP_RELEASE_TAG}"
  UPGRADE_DATABASE_BACKUP="${UPGRADE_STATE_BACKUP_DIR}/bubblesharkpanel.sqlite"
  database_path="${PANEL_DATA_DIR}/${PANEL_DB_FILENAME}"
  run_as_root mkdir -p "${UPGRADE_STATE_BACKUP_DIR}"

  if try_as_root test -f "${PANEL_ENV_FILE}"; then
    run_as_root cp -p "${PANEL_ENV_FILE}" "${UPGRADE_STATE_BACKUP_DIR}/panel.env"
  fi
  if try_as_root test -f "${PANEL_COMPOSE_FILE}"; then
    run_as_root cp -p "${PANEL_COMPOSE_FILE}" "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.yml"
  fi
  if try_as_root test -f "${PANEL_BIND_COMPOSE_FILE}"; then
    run_as_root cp -p "${PANEL_BIND_COMPOSE_FILE}" "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.bind.yml"
  fi
  if try_as_root test -f "${database_path}"; then
    run_as_root sqlite3 "${database_path}" ".backup '${UPGRADE_DATABASE_BACKUP}'"
    run_as_root chmod 0600 "${UPGRADE_DATABASE_BACKUP}"
  else
    UPGRADE_DATABASE_BACKUP=""
  fi
  log_info "Upgrade state backed up to ${UPGRADE_STATE_BACKUP_DIR}."
}

restore_existing_install_state() {
  local database_path="${PANEL_DATA_DIR}/${PANEL_DB_FILENAME}"
  if [[ -z "${UPGRADE_STATE_BACKUP_DIR}" ]] || ! try_as_root test -d "${UPGRADE_STATE_BACKUP_DIR}"; then
    return
  fi
  if try_as_root test -f "${UPGRADE_STATE_BACKUP_DIR}/panel.env"; then
    run_as_root cp -p "${UPGRADE_STATE_BACKUP_DIR}/panel.env" "${PANEL_ENV_FILE}"
  fi
  if try_as_root test -f "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.yml"; then
    run_as_root cp -p "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.yml" "${PANEL_COMPOSE_FILE}"
  fi
  if try_as_root test -f "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.bind.yml"; then
    run_as_root cp -p "${UPGRADE_STATE_BACKUP_DIR}/docker-compose.bind.yml" "${PANEL_BIND_COMPOSE_FILE}"
  fi
  if [[ -n "${UPGRADE_DATABASE_BACKUP}" ]] && try_as_root test -f "${UPGRADE_DATABASE_BACKUP}"; then
    run_as_root cp "${UPGRADE_DATABASE_BACKUP}" "${database_path}"
    if [[ "${RESOLVED_INSTALL_MODE}" == "native" ]]; then
      run_as_root chown "${NATIVE_SERVICE_USER}:${NATIVE_SERVICE_GROUP}" "${database_path}"
    fi
  fi
  log_warn "Restored configuration and database from ${UPGRADE_STATE_BACKUP_DIR}."
}

# 将安装进度写入状态文件，便于审计和排障。
write_status() {
  local stage status message timestamp
  stage="$1"
  status="$2"
  message="$3"
  # --check 承诺不改动系统：连状态文件都不写（它位于 /var/log 下，需要提权创建）。
  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    return 0
  fi
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  run_as_root mkdir -p "${PANEL_LOG_DIR}"
  printf '%s [%s] [%s] %s\n' "${timestamp}" "${stage}" "${status}" "${message}" | run_as_root tee -a "${STATUS_FILE}" >/dev/null
}

begin_stage() {
  CURRENT_STAGE="$1"
  write_status "$1" "start" "$2"
}

# -----------------------------------------------------------------------------
# 前置体检：报告同时打印到终端与落盘，用户与事后排查看到的是同一份内容。
# -----------------------------------------------------------------------------
# 重置报告文件（不删除由调用方通过 CHECK_REPORT_FILE 指定的路径，--check 结束要打印它）。
reset_check_report() {
  if [[ -n "${CHECK_REPORT_FILE}" ]]; then
    : > "${CHECK_REPORT_FILE}" 2>/dev/null || true
  fi
}

# 追加一行报告：始终打印，同时尽力写入报告文件；写不进去不能影响安装主流程。
# 每行都记进 PREFLIGHT_REPORT_LINES，安装模式下再整段写进状态文件，事后排查看到的是同一份内容。
append_install_report() {
  local line="$*"
  printf '%s\n' "${line}"
  PREFLIGHT_REPORT_LINES+=("${line}")
  if [[ -n "${CHECK_REPORT_FILE}" ]]; then
    printf '%s\n' "${line}" >> "${CHECK_REPORT_FILE}" 2>/dev/null || true
  fi
}

# 报告默认只打印到终端：落盘会创建目录或文件，与 --check「不改动系统」的承诺冲突，
# 所以要让报告留档时由调用方显式给出 CHECK_REPORT_FILE。
resolve_check_report_path() {
  if [[ "${CHECK_ONLY}" -ne 1 ]]; then
    return
  fi
  if [[ -n "${CHECK_REPORT_FILE}" ]]; then
    reset_check_report
  fi
}

# 三态条目：0=通过，1=警告，2=不通过（安装会被中止）。
report_item() {
  local level="$1"
  local label="$2"
  local detail="$3"
  local mark
  case "${level}" in
    0) mark="OK   " ;;
    1) mark="WARN " ;;
    *) mark="FAIL " ;;
  esac
  append_install_report "  [${mark}] ${label}：${detail}"
}

# 失败时给一条能照着做的下一步，而不是让用户面对诊断日志。
report_next_step() {
  append_install_report "  下一步：$*"
}

record_install_error() {
  LAST_ERROR_EXIT_CODE="$1"
  LAST_ERROR_LINE="$2"
}

collect_install_diagnostics() {
  local exit_code="$1"
  local line_number="$2"
  local report

  report="$(mktemp)"
  {
    printf 'timestamp=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'stage=%s\n' "${CURRENT_STAGE}"
    printf 'exit_code=%s\n' "${exit_code}"
    printf 'line=%s\n' "${line_number}"
    printf 'release=%s\n' "${BSP_RELEASE_TAG}"
    printf 'install_mode=%s\n' "${RESOLVED_INSTALL_MODE:-${INSTALL_MODE}}"
    printf 'network_profile=%s\n' "${RESOLVED_NETWORK_PROFILE:-${NETWORK_PROFILE}}"
    printf 'panel_image=%s\n' "${PANEL_IMAGE}"
    printf 'dst_image=%s\n' "${BSP_GAME_DST_IMAGE}"
    printf 'steamcmd_image=%s\n' "${BSP_STEAMCMD_IMAGE}"
    printf 'distro=%s\n' "${DISTRO_ID:-unknown}"
    printf 'architecture=%s\n' "$(uname -m 2>/dev/null || printf unknown)"
    printf '\n[disk]\n'
    df -h "${PANEL_INSTALL_DIR}" 2>&1 || true
    printf '\n[memory]\n'
    free -m 2>&1 || true
    if [[ "${BSP_DIAGNOSTICS_SKIP_DOCKER:-0}" != "1" ]] && command -v docker >/dev/null 2>&1; then
      printf '\n[docker-version]\n'
      docker version 2>&1 || true
      if [[ -f "${PANEL_ENV_FILE}" && -f "${PANEL_COMPOSE_FILE}" && -f "${PANEL_BIND_COMPOSE_FILE}" ]]; then
        printf '\n[compose-ps]\n'
        try_as_root docker compose --env-file "${PANEL_ENV_FILE}" -f "${PANEL_COMPOSE_FILE}" -f "${PANEL_BIND_COMPOSE_FILE}" ps -a 2>&1 || true
      fi
    fi
    if [[ "${RESOLVED_INSTALL_MODE:-}" == "native" ]] && command -v systemctl >/dev/null 2>&1; then
      printf '\n[native-service]\n'
      try_as_root systemctl status ${PANEL_NATIVE_SERVICE} --no-pager 2>&1 || true
      printf '\n[native-journal]\n'
      try_as_root journalctl -u ${PANEL_NATIVE_SERVICE} -n 80 --no-pager 2>&1 || true
    fi
  } >"${report}"

  try_as_root mkdir -p "${PANEL_LOG_DIR}" || true
  try_as_root cp "${report}" "${DIAGNOSTICS_FILE}" || true
  try_as_root chmod 600 "${DIAGNOSTICS_FILE}" || true
  rm -f "${report}"
}

handle_install_exit() {
  local exit_code="$1"
  trap - ERR EXIT
  if [[ "${INSTALL_COMPLETED}" -eq 1 || "${exit_code}" -eq 0 ]]; then
    return
  fi

  # --check 只体检：失败时报告已经打印过原因与下一步，这里不再生成诊断、更不执行回滚。
  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    if [[ -n "${PREFLIGHT_NEXT_STEP}" ]]; then
      log_error "下一步：${PREFLIGHT_NEXT_STEP}"
    fi
    if [[ -n "${CHECK_REPORT_FILE}" ]]; then
      log_error "体检报告：${CHECK_REPORT_FILE}"
    fi
    return
  fi

  set +e
  if try_as_root mkdir -p "${PANEL_LOG_DIR}"; then
    printf '%s [%s] [error] %s; exit=%s; line=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${CURRENT_STAGE}" "${LAST_ERROR_MESSAGE}" "${exit_code}" "${LAST_ERROR_LINE}" | try_as_root tee -a "${STATUS_FILE}" >/dev/null || true
  fi
  collect_install_diagnostics "${exit_code}" "${LAST_ERROR_LINE}" || true
  rollback_install || true
  log_error "Installation failed during stage '${CURRENT_STAGE}' (exit ${exit_code}, line ${LAST_ERROR_LINE})."
  # 先给「下一步」再给诊断文件：用户需要的是动作，不是路径。
  if [[ -n "${PREFLIGHT_NEXT_STEP}" ]]; then
    log_error "下一步：${PREFLIGHT_NEXT_STEP}"
  fi
  log_error "Diagnostics: ${DIAGNOSTICS_FILE}"
  log_error "Status history: ${STATUS_FILE}"
}

# 为网络/包管理等易受瞬时故障影响的操作提供重试能力。
run_with_retry() {
  local description attempt
  description="$1"
  shift

  attempt=1
  while (( attempt <= RETRY_MAX )); do
    if "$@"; then
      return 0
    fi

    if (( attempt == RETRY_MAX )); then
      log_error "${description} failed after ${RETRY_MAX} attempts."
      return 1
    fi

    log_warn "${description} failed on attempt ${attempt}, retrying in ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
    attempt=$((attempt + 1))
  done
}

# 将资源源追加到镜像池（自动去重）。
append_installer_repo_source() {
  local source="$1"
  local existing

  source="${source#"${source%%[![:space:]]*}"}"
  source="${source%"${source##*[![:space:]]}"}"
  source="${source%/}"
  if [[ -z "${source}" ]]; then
    return
  fi

  for existing in "${INSTALLER_REPO_POOL[@]}"; do
    if [[ "${existing}" == "${source}" ]]; then
      return
    fi
  done
  INSTALLER_REPO_POOL+=("${source}")
}

# 生成 GitHub 资源候选列表（逗号分隔）：加速代理前缀 → 直连。BSP_GITHUB_PROXY 设置时仅走该代理 + 直连。
build_github_url_variants() {
  local direct_url="$1"
  local proxy site
  local -a parts=()

  if [[ -n "${BSP_GITHUB_PROXY}" ]]; then
    proxy="${BSP_GITHUB_PROXY%/}"
    parts+=("${proxy}/${direct_url}")
  else
    local old_ifs="${IFS}"
    IFS=","
    for site in ${GITHUB_PROXY_SITES}; do
      parts+=("${site%/}/${direct_url}")
    done
    IFS="${old_ifs}"
  fi
  parts+=("${direct_url}")
  local old_ifs2="${IFS}"
  IFS=","
  echo "${parts[*]}"
  IFS="${old_ifs2}"
}

# 初始化安装资源镜像池（INSTALLER_REPO_RAW 优先，其次 INSTALLER_REPO_MIRRORS，为空时按代理清单自动生成）。
init_installer_repo_pool() {
  local item
  local raw_sources

  if [[ "${INSTALLER_REPO_POOL_INITIALIZED}" -eq 1 ]]; then
    return
  fi

  if [[ -z "${INSTALLER_REPO_MIRRORS}" ]]; then
    INSTALLER_REPO_MIRRORS="https://cdn.jsdelivr.net/gh/PMAT77/bubble-shark-panel@${BSP_RELEASE_TAG},$(build_github_url_variants "https://raw.githubusercontent.com/PMAT77/bubble-shark-panel/${BSP_RELEASE_TAG}")"
  fi

  if [[ -n "${INSTALLER_REPO_RAW}" ]]; then
    append_installer_repo_source "${INSTALLER_REPO_RAW}"
  fi

  IFS=',' read -r -a raw_sources <<< "${INSTALLER_REPO_MIRRORS}"
  for item in "${raw_sources[@]}"; do
    append_installer_repo_source "${item}"
  done

  if [[ "${#INSTALLER_REPO_POOL[@]}" -eq 0 ]]; then
    abort "Installer mirrors are empty. Please set INSTALLER_REPO_MIRRORS or INSTALLER_REPO_RAW."
  fi

  INSTALLER_REPO_POOL_INITIALIZED=1
  log_info "Installer asset mirrors: ${INSTALLER_REPO_POOL[*]}"
}

# 从安装资源镜像池下载文件到目标路径（自动多源回退 + 重试）。
download_installer_asset() {
  local relative_path="$1"
  local dest_path="$2"
  local source url attempt tmp_file

  init_installer_repo_pool
  for source in "${INSTALLER_REPO_POOL[@]}"; do
    for ((attempt = 1; attempt <= REPO_DOWNLOAD_MAX_ATTEMPTS; attempt++)); do
      url="${source}/${relative_path}"
      tmp_file="$(mktemp)"
      if curl -fL --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" --max-time "${REPO_DOWNLOAD_TIMEOUT_SECONDS}" -o "${tmp_file}" "${url}" >/dev/null 2>&1; then
        if ! verify_installer_asset_checksum "${relative_path}" "${tmp_file}"; then
          rm -f "${tmp_file}"
          log_warn "Checksum verify failed: ${url} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS})"
          if (( attempt < REPO_DOWNLOAD_MAX_ATTEMPTS )); then
            sleep "${RETRY_DELAY_SECONDS}"
          fi
          continue
        fi
        run_as_root install -m 0644 "${tmp_file}" "${dest_path}"
        rm -f "${tmp_file}"
        log_info "Downloaded ${relative_path} from ${source} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS})"
        return 0
      fi

      rm -f "${tmp_file}"
      log_warn "Download failed: ${url} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS})"
      if (( attempt < REPO_DOWNLOAD_MAX_ATTEMPTS )); then
        sleep "${RETRY_DELAY_SECONDS}"
      fi
    done
  done

  return 1
}

# 返回随安装脚本发布的资源摘要。校验不能再次依赖 GitHub Raw，否则镜像回退仍会在国内网络失败。
resolve_installer_asset_sha256() {
  case "$1" in
    docker-compose.yml)
      printf '%s' "${INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_YML}"
      ;;
    docker-compose.bind.yml)
      printf '%s' "${INSTALLER_ASSET_SHA256_DOCKER_COMPOSE_BIND_YML}"
      ;;
    *)
      return 1
      ;;
  esac
}

# 对镜像源下载的安装资源做完整性校验（摘要固定在当前版本安装脚本中）。
verify_installer_asset_checksum() {
  local relative_path="$1"
  local downloaded_file="$2"
  local expected_sum actual_sum

  if [[ "${STRICT_INSTALLER_ASSET_CHECKSUM}" != "1" ]]; then
    return 0
  fi

  if ! expected_sum="$(resolve_installer_asset_sha256 "${relative_path}")" || [[ -z "${expected_sum}" ]]; then
    # 未登记摘要的资源（如 scripts/bsp.sh）只告警放行。把「没有内置摘要」当成校验失败，
    # 会让这些资源在所有镜像源上都被判成下载失败并被静默跳过（bsp CLI 因此永远装不上）。
    log_warn "No embedded checksum for installer asset, skipping verification: ${relative_path}"
    return 0
  fi

  actual_sum="$(sha256sum "${downloaded_file}" | awk '{print $1}')"

  if [[ "${expected_sum}" != "${actual_sum}" ]]; then
    log_warn "Checksum mismatch for ${relative_path}: expected ${expected_sum}, got ${actual_sum}"
    return 1
  fi

  return 0
}

# 写入脚本内置的 panel.env 预设资源，避免弱网环境拉取 preset 失败。
write_builtin_panel_env_preset_asset() {
  local item="$1"
  local dest_path="$2"
  local content

  # 用命令替换内的 heredoc 承载内容，再由 tee 落盘。
  # 不要写成 run_as_root bash -c "... <<EOF"：heredoc 必须由同一个 shell 解析后续行，
  # 包在 bash -c 的双引号里会让内层 shell 把内容当命令执行。
  case "${item}" in
    small.env)
      content="$(cat <<'EOF'
# GSH 内存预设：small（总内存约 4 GiB，< 5 GiB）
# 合并到 panel.env 后重启 panel。勿与 dev 压力测试用的大上限（如 5120）混用。
BSP_STEAMCMD_CONTAINER_MEMORY_MB=1536
BSP_STEAMCMD_CONTAINER_MEMORY_SWAP_MB=1536
BSP_DST_CONTAINER_MEMORY_MB=1536
BSP_HOST_STEAMCMD_PLANNING_MB=1280
BSP_HOST_MEMORY_HEADROOM_MB=384
BSP_HOST_DST_PLANNING_MB=512
EOF
)"
      ;;
    medium.env)
      content="$(cat <<'EOF'
# GSH 内存预设：medium（总内存约 6 GiB，5 GiB–8 GiB）
BSP_STEAMCMD_CONTAINER_MEMORY_MB=2048
BSP_STEAMCMD_CONTAINER_MEMORY_SWAP_MB=2048
BSP_DST_CONTAINER_MEMORY_MB=1536
BSP_HOST_STEAMCMD_PLANNING_MB=1280
BSP_HOST_MEMORY_HEADROOM_MB=512
BSP_HOST_DST_PLANNING_MB=768
EOF
)"
      ;;
    large.env)
      content="$(cat <<'EOF'
# GSH 内存预设：large（总内存 ≥ 8 GiB）
# 高配默认不设子容器硬上限，由 DST/SteamCMD 按需使用；若需防止单容器失控可取消注释：
# BSP_STEAMCMD_CONTAINER_MEMORY_MB=4096
# BSP_DST_CONTAINER_MEMORY_MB=8192
BSP_HOST_MEMORY_HEADROOM_MB=512
EOF
)"
      ;;
    README.md)
      content="$(cat <<'EOF'
# panel.env 内存预设

按宿主机 **总内存（MemTotal）** 选用预设，写入 `panel.env` 中的 **可选** 子容器内存上限与安装守卫参数。  
默认生产安装**不强制**上限（高配可跑满 Mod）；小内存机建议显式启用预设，避免误设过大上限（如压力测试用的 5120 MiB）。

| 预设文件 | 适用总内存 | 说明 |
|----------|------------|------|
| `small.env` | 约 4 GiB（&lt; 5 GiB） | 单实例地上、少 Mod；不建议洞穴 |
| `medium.env` | 约 6 GiB（5–8 GiB） | 单实例 + 洞穴 + 中等 Mod |
| `large.env` | ≥ 8 GiB | 默认不设硬上限；可按需取消注释 |

## 用法

**安装脚本自动档位**（默认 `BSP_PANEL_ENV_PRESET=auto`）：

```bash
sudo bash ./scripts/install.linux.sh
# 显式指定：sudo BSP_PANEL_ENV_PRESET=small bash ./scripts/install.linux.sh
```

**已安装后手动合并**（保留现有 `panel.env`，追加预设行）：

```bash
sudo bash -c 'cat /opt/bubblesharkpanel/config/panel.env.presets/small.env >> /opt/bubblesharkpanel/panel.env'
# 安装脚本会将预设同步到 PANEL_INSTALL_DIR/config/panel.env.presets/
cd /opt/bubblesharkpanel
sudo docker compose --env-file panel.env -f docker-compose.yml -f docker-compose.bind.yml up -d
```

完整说明见 [docs/MEMORY.md](../../docs/MEMORY.md)。
EOF
)"
      ;;
    *)
      return 1
      ;;
  esac

  printf '%s\n' "${content}" | run_as_root tee "${dest_path}" >/dev/null

  return 0
}

# 兼容旧调用点：network profile 打分仍以 GHCR 可达性作为 global 档位信号。
check_ghcr_reachability() {
  check_registry_reachability "ghcr.io"
}

# 生成三个镜像键（v0.2.0 统一镜像：三键同值；PANEL_IMAGE_OVERRIDE 设置时直接采用）。
finalize_image_refs() {
  if [[ -n "${PANEL_IMAGE_OVERRIDE}" ]]; then
    PANEL_IMAGE="${PANEL_IMAGE_OVERRIDE}"
    BSP_GAME_DST_IMAGE="${PANEL_IMAGE_OVERRIDE}"
    BSP_STEAMCMD_IMAGE="${PANEL_IMAGE_OVERRIDE}"
    INSTALL_STEAMCMD_PULL_IMAGE="${PANEL_IMAGE_OVERRIDE}"
    log_info "Image override in effect: ${PANEL_IMAGE}"
    return
  fi
  PANEL_IMAGE="ghcr.io/pmat77/bubblesharkpanel:${PANEL_IMAGE_TAG}"
  BSP_GAME_DST_IMAGE="${PANEL_IMAGE}"
  BSP_STEAMCMD_IMAGE="${PANEL_IMAGE}"
  INSTALL_STEAMCMD_PULL_IMAGE="${PANEL_IMAGE}"
  log_info "Panel image: ${PANEL_IMAGE}"
  log_info "DST image: ${BSP_GAME_DST_IMAGE}"
  log_info "SteamCMD image: ${BSP_STEAMCMD_IMAGE}"
}

# 基于实际连通性选择网络档位，不通过 IP 地理接口收集服务器位置。
resolve_network_profile() {
  local global_score=0

  case "${NETWORK_PROFILE}" in
    cn|global)
      RESOLVED_NETWORK_PROFILE="${NETWORK_PROFILE}"
      ;;
    auto)
      probe_https_url "https://raw.githubusercontent.com/" 5 && global_score=$((global_score + 1))
      probe_https_url "https://download.docker.com/" 5 && global_score=$((global_score + 1))
      check_ghcr_reachability >/dev/null 2>&1 && global_score=$((global_score + 1))
      if [[ "${global_score}" -ge 2 ]]; then
        RESOLVED_NETWORK_PROFILE="global"
      elif probe_https_url "${DEBIAN_MIRROR_URL}/" 5; then
        RESOLVED_NETWORK_PROFILE="cn"
      else
        RESOLVED_NETWORK_PROFILE="global"
        log_warn "Unable to confirm a reachable CN mirror; retaining global sources."
      fi
      ;;
    *)
      abort "Invalid network profile '${NETWORK_PROFILE}'. Expected auto, cn or global."
      ;;
  esac

  if [[ "${RESOLVED_NETWORK_PROFILE}" == "cn" ]]; then
    USE_CN_DEBIAN_MIRROR=1
    log_info "Network profile: cn (distribution mirror + extended SteamCMD retries)."
  else
    log_info "Network profile: global."
  fi
}

resolve_install_mode() {
  case "${INSTALL_MODE}" in
    docker|native)
      RESOLVED_INSTALL_MODE="${INSTALL_MODE}"
      ;;
    auto)
      if command -v docker >/dev/null 2>&1; then
        RESOLVED_INSTALL_MODE="docker"
      elif [[ -t 0 && -t 1 ]]; then
        printf 'Select deployment mode [1=Docker (recommended for communities), 2=Native systemd]: '
        local answer
        read -r answer
        case "${answer}" in
          2|native|Native)
            RESOLVED_INSTALL_MODE="native"
            ;;
          *)
            RESOLVED_INSTALL_MODE="docker"
            ;;
        esac
      else
        # 非交互场景保持 Docker 默认值；若失败会给出显式 Native 重试命令，不静默改变隔离模型。
        RESOLVED_INSTALL_MODE="docker"
      fi
      ;;
    *)
      abort "Invalid install mode '${INSTALL_MODE}'. Expected auto, docker or native."
      ;;
  esac
  log_info "Deployment mode: ${RESOLVED_INSTALL_MODE}."
}

# 校验系统是否提供 apt-get（仅支持 Debian/Ubuntu 体系）。
ensure_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
      abort "RHEL/Rocky/Alma hosts are supported in docker mode only (native systemd packaging is Debian/Ubuntu). Rerun with --mode docker."
    fi
    abort "Only Debian/Ubuntu systems with apt are supported."
  fi
}

# 识别发行版与代号，用于后续 apt 仓库配置。
detect_distro() {
  if [[ ! -f /etc/os-release ]]; then
    abort "/etc/os-release not found. Unsupported Linux distribution."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO_ID="${ID:-}"
  DISTRO_CODENAME="${VERSION_CODENAME:-}"

  if [[ -z "${DISTRO_ID}" ]]; then
    abort "Cannot detect Linux distribution."
  fi

  if [[ "${DISTRO_ID}" != "ubuntu" && "${DISTRO_ID}" != "debian" ]]; then
    abort "Unsupported distribution: ${DISTRO_ID}. Only Ubuntu/Debian are supported."
  fi

  if [[ -z "${DISTRO_CODENAME}" && -n "${VERSION:-}" ]]; then
    DISTRO_CODENAME="$(echo "${VERSION}" | awk -F'[() ]' '{print $2}')"
  fi

  if [[ -z "${DISTRO_CODENAME}" ]]; then
    abort "Cannot detect distro codename from /etc/os-release."
  fi
}

# 统一 apt 安装入口，使用非交互模式避免阻塞。
apt_install() {
  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# 备份 apt 源配置，便于失败时恢复到系统默认。
backup_apt_sources() {
  run_as_root rm -rf "${APT_SOURCES_BACKUP_DIR}"
  run_as_root mkdir -p "${APT_SOURCES_BACKUP_DIR}"

  if run_as_root test -f /etc/apt/sources.list; then
    run_as_root cp /etc/apt/sources.list "${APT_SOURCES_BACKUP_DIR}/sources.list"
  fi

  if run_as_root test -f /etc/apt/sources.list.d/debian.sources; then
    run_as_root cp /etc/apt/sources.list.d/debian.sources "${APT_SOURCES_BACKUP_DIR}/debian.sources"
  fi

  if run_as_root test -f /etc/apt/sources.list.d/ubuntu.sources; then
    run_as_root cp /etc/apt/sources.list.d/ubuntu.sources "${APT_SOURCES_BACKUP_DIR}/ubuntu.sources"
  fi
}

# 恢复 apt 源配置到脚本运行前状态。
restore_apt_sources_backup() {
  if run_as_root test -f "${APT_SOURCES_BACKUP_DIR}/sources.list"; then
    run_as_root cp "${APT_SOURCES_BACKUP_DIR}/sources.list" /etc/apt/sources.list
  else
    run_as_root rm -f /etc/apt/sources.list
  fi

  if run_as_root test -f "${APT_SOURCES_BACKUP_DIR}/debian.sources"; then
    run_as_root cp "${APT_SOURCES_BACKUP_DIR}/debian.sources" /etc/apt/sources.list.d/debian.sources
  else
    run_as_root rm -f /etc/apt/sources.list.d/debian.sources
  fi

  if run_as_root test -f "${APT_SOURCES_BACKUP_DIR}/ubuntu.sources"; then
    run_as_root cp "${APT_SOURCES_BACKUP_DIR}/ubuntu.sources" /etc/apt/sources.list.d/ubuntu.sources
  else
    run_as_root rm -f /etc/apt/sources.list.d/ubuntu.sources
  fi
}

# 将 Debian apt 源切换为国内镜像（bookworm/bookworm-updates/bookworm-backports/security）。
apply_cn_debian_mirror() {
  run_as_root rm -f /etc/apt/sources.list.d/debian.sources
  run_as_root bash -c "cat > /etc/apt/sources.list <<EOF
deb ${DEBIAN_MIRROR_URL} ${DISTRO_CODENAME} main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR_URL} ${DISTRO_CODENAME}-updates main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR_URL} ${DISTRO_CODENAME}-backports main contrib non-free non-free-firmware
deb ${DEBIAN_SECURITY_MIRROR_URL} ${DISTRO_CODENAME}-security main contrib non-free non-free-firmware
EOF"
}

# 将 Ubuntu apt 源切换为国内镜像；发行版签名仍由系统密钥验证。
apply_cn_ubuntu_mirror() {
  run_as_root rm -f /etc/apt/sources.list.d/ubuntu.sources
  run_as_root bash -c "cat > /etc/apt/sources.list <<EOF
deb ${UBUNTU_MIRROR_URL} ${DISTRO_CODENAME} main restricted universe multiverse
deb ${UBUNTU_MIRROR_URL} ${DISTRO_CODENAME}-updates main restricted universe multiverse
deb ${UBUNTU_MIRROR_URL} ${DISTRO_CODENAME}-backports main restricted universe multiverse
deb ${UBUNTU_MIRROR_URL} ${DISTRO_CODENAME}-security main restricted universe multiverse
EOF"
}

# Debian / Ubuntu 优先使用国内镜像；失败则回退系统默认源。
prepare_apt_sources() {
  if [[ "${USE_CN_DEBIAN_MIRROR}" != "1" ]]; then
    run_with_retry "apt-get update" run_as_root apt-get update -y || abort "apt-get update failed."
    return
  fi

  backup_apt_sources
  if [[ "${DISTRO_ID}" == "debian" ]]; then
    apply_cn_debian_mirror
  else
    apply_cn_ubuntu_mirror
  fi

  if run_with_retry "apt-get update with CN mirror" run_as_root apt-get update -y; then
    log_info "Using CN ${DISTRO_ID} mirror."
    return
  fi

  log_warn "CN mirror update failed. Rolling back to default apt sources..."
  restore_apt_sources_backup
  run_with_retry "apt-get update after rollback" run_as_root apt-get update -y || abort "apt-get update failed after rollback."
}

# 安装后续步骤所需的基础依赖。
install_base_packages() {
  log_info "Installing base packages..."
  prepare_apt_sources
  apt_install ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https jq sqlite3
}

# 配置 Docker 官方 apt 仓库与 GPG key。
configure_docker_repo() {
  local arch repo keyring
  arch="$(dpkg --print-architecture)"
  keyring="/etc/apt/keyrings/docker.gpg"
  repo="https://download.docker.com/linux/${DISTRO_ID}"

  log_info "Configuring Docker apt repository..."
  run_as_root install -m 0755 -d /etc/apt/keyrings
  run_as_root rm -f "${keyring}"
  if ! curl -fsSL --connect-timeout 8 --max-time 30 "${repo}/gpg" | run_as_root gpg --dearmor -o "${keyring}"; then
    log_warn "Unable to download Docker repository signing key from ${repo}."
    return 1
  fi
  run_as_root chmod a+r "${keyring}"
  run_as_root bash -c "echo 'deb [arch=${arch} signed-by=${keyring}] ${repo} ${DISTRO_CODENAME} stable' > /etc/apt/sources.list.d/docker.list"
}

# 发行版源不含 Compose v2（如 Debian 12）时，从 docker/compose GitHub Release 补装 CLI 插件。
# 下载复用安装器的 GitHub 加速代理池；插件为全用户安装（Docker 官方文档路径 /usr/local/lib/docker/cli-plugins）。
ensure_compose_plugin() {
  local arch asset expected_sum actual_sum source attempt tmp_file
  if run_as_root docker compose version >/dev/null 2>&1; then
    log_info "Docker Compose v2 plugin already available."
    return 0
  fi

  case "$(uname -m)" in
    x86_64)
      arch="x86_64"
      expected_sum="${COMPOSE_PLUGIN_SHA256_X86_64}"
      ;;
    aarch64)
      arch="aarch64"
      expected_sum="${COMPOSE_PLUGIN_SHA256_AARCH64}"
      ;;
    *)
      log_warn "Compose plugin auto-install unsupported on $(uname -m); install the plugin manually."
      return 1
      ;;
  esac
  asset="docker-compose-linux-${arch}"

  local variants
  local raw_sources=()
  variants="$(build_github_url_variants "https://github.com/docker/compose/releases/download/${COMPOSE_PLUGIN_VERSION}/${asset}")"
  IFS=',' read -r -a raw_sources <<< "${variants}"

  for source in "${raw_sources[@]}"; do
    for ((attempt = 1; attempt <= REPO_DOWNLOAD_MAX_ATTEMPTS; attempt++)); do
      tmp_file="$(mktemp)"
      log_info "Downloading Compose v2 plugin from ${source} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS}; progress below)..."
      # 不加 -s：弱网下让 curl 输出进度，避免“看似卡死”；--retry-all-errors 让同一源上的断流自己重试。
      if curl -fL --progress-bar --retry 3 --retry-delay 3 --retry-all-errors \
        --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${COMPOSE_PLUGIN_MAX_TIME_SECONDS}" \
        -o "${tmp_file}" \
        "${source}"; then
        actual_sum="$(sha256sum "${tmp_file}" | awk '{print $1}')"
        if [[ "${actual_sum}" == "${expected_sum}" ]]; then
          run_as_root install -d -m 0755 /usr/local/lib/docker/cli-plugins
          run_as_root install -m 0755 "${tmp_file}" "${COMPOSE_PLUGIN_INSTALL_PATH}"
          rm -f "${tmp_file}"
          if run_as_root docker compose version >/dev/null 2>&1; then
            log_info "Docker Compose v2 plugin installed: ${COMPOSE_PLUGIN_INSTALL_PATH}"
            return 0
          fi
          log_warn "Compose plugin installed but 'docker compose version' still fails; manual steps required."
          return 1
        fi
        log_warn "Checksum mismatch for ${source} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS}): expected ${expected_sum}, got ${actual_sum}."
      else
        log_warn "Download failed: ${source} (attempt ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS})."
      fi
      rm -f "${tmp_file}"
      if (( attempt < REPO_DOWNLOAD_MAX_ATTEMPTS )); then
        sleep "${RETRY_DELAY_SECONDS}"
      fi
    done
  done

  log_error "Unable to auto-install the Docker Compose v2 plugin from ${COMPOSE_PLUGIN_VERSION} (all sources failed or checksum mismatch)."
  log_error "请手动安装 Compose v2 插件后原样重跑本安装器（命令见 docs/install-docker.md 的「常见错误」）："
  log_error "  sudo mkdir -p /usr/local/lib/docker/cli-plugins"
  log_error "  sudo curl -fL --retry 3 \"https://gh-proxy.com/https://github.com/docker/compose/releases/download/${COMPOSE_PLUGIN_VERSION}/${asset}\" -o /usr/local/lib/docker/cli-plugins/docker-compose"
  log_error "  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose"
  log_error "  docker compose version   # 期望输出：Docker Compose version ${COMPOSE_PLUGIN_VERSION}"
  return 1
}

# 安装 Docker（如未安装），并确保守护进程与 compose 插件可用。
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log_info "Docker already installed. Skipping package installation."
  else
    if configure_docker_repo \
      && run_as_root apt-get update -y \
      && apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
      log_info "Docker CE installed from the official repository."
    else
      log_warn "Docker CE repository is unavailable. Falling back to signed distribution packages (docker.io; ~90 MB download + ~640 MB unpack — slow on weak networks is normal, safe to Ctrl+C and rerun later)."
      write_status "dependencies" "warn" "Docker CE repo unreachable; falling back to distro docker.io"
      run_as_root rm -f /etc/apt/sources.list.d/docker.list
      run_as_root apt-get update -y || return 1
      if ! apt-cache show docker-compose-v2 >/dev/null 2>&1 \
        && ! apt-cache show docker-compose-plugin >/dev/null 2>&1 \
        && ! apt-cache show docker-compose 2>/dev/null | grep -q '^Version: 2'; then
        log_info "Distribution repos provide no Compose v2; the plugin will be auto-installed from GitHub Release (proxy-accelerated, ~65 MB) once Docker is in place."
      fi
      apt_install docker.io || return 1
      if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
        # Ubuntu 22.04（jammy-updates）+/Debian 13+：官方源收录的 Compose v2
        apt_install docker-compose-v2 || return 1
      elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        # Docker 官方 apt 源的插件包
        apt_install docker-compose-plugin || return 1
      elif apt-cache show docker-compose 2>/dev/null | grep -q '^Version: 2'; then
        # Debian 13+：官方源打包的 Compose v2（包名 docker-compose；Debian 12 同名包是 v1，版本不匹配不会误装）
        apt_install docker-compose || return 1
      else
        # Debian 12：发行版源无 Compose v2，走 GitHub Release 自动补装（gh-proxy 加速 + 官方 sha256 校验）
        ensure_compose_plugin || return 1
      fi
    fi
  fi

  log_info "Ensuring Docker service is enabled..."
  run_as_root systemctl enable --now docker || return 1
  if ! run_as_root docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose v2 plugin is required but unavailable."
    return 1
  fi
}

# 将当前执行用户加入 docker 组，避免非 root 场景下无法使用 Docker CLI。
add_user_to_docker_group() {
  local target_user
  target_user="${SUDO_USER:-${USER:-}}"

  if [[ -z "${target_user}" ]]; then
    log_warn "Cannot determine target user for docker group assignment."
    return
  fi

  if [[ "${target_user}" == "root" ]]; then
    return
  fi

  if ! getent group docker >/dev/null 2>&1; then
    run_as_root groupadd docker
  fi

  run_as_root usermod -aG docker "${target_user}" || true
  log_info "Added ${target_user} to docker group. Re-login is required for group changes to take effect."
}

install_native_dependencies() {
  if [[ "$(uname -m)" != "x86_64" ]]; then
    abort "Native mode currently supports x86_64 only. ARM64 remains experimental and has no Release artifact."
  fi
  if ! dpkg --print-foreign-architectures | grep -Fxq i386; then
    run_as_root dpkg --add-architecture i386
    run_as_root apt-get update -y
  fi
  # 与统一镜像使用同一套 32 位运行库（见 docker/unified/Dockerfile）：Docker 分支已实测，
  # Native 分支此前缺 libcurl4:i386、lib32stdc++6、libcurl3-gnutls，干净系统上 DST 与
  # SteamCMD 可能起不来。
  apt_install tar gzip xz-utils ca-certificates curl util-linux lib32gcc-s1 lib32stdc++6 libc6-i386 libcurl3-gnutls libcurl4 libcurl4:i386 libgcc-s1 libstdc++6 libstdc++6:i386
}

ensure_native_service_user() {
  if ! getent group "${NATIVE_SERVICE_GROUP}" >/dev/null 2>&1; then
    run_as_root groupadd --system "${NATIVE_SERVICE_GROUP}"
  fi
  if ! id "${NATIVE_SERVICE_USER}" >/dev/null 2>&1; then
    run_as_root useradd \
      --system \
      --gid "${NATIVE_SERVICE_GROUP}" \
      --home-dir "${NATIVE_USER_HOME}" \
      --create-home \
      --shell /usr/sbin/nologin \
      "${NATIVE_SERVICE_USER}"
  else
    # 用户已存在但 home 与本次预期不一致时以系统登记的为准：
    # systemd --user 只读取 $HOME/.config/systemd/user，写错目录会导致开服报 unit not found。
    local existing_home
    existing_home="$(getent passwd "${NATIVE_SERVICE_USER}" | cut -d: -f6)"
    if [[ -n "${existing_home}" && "${existing_home}" != "${NATIVE_USER_HOME}" ]]; then
      log_warn "User ${NATIVE_SERVICE_USER} already exists with home ${existing_home}; using it instead of ${NATIVE_USER_HOME}."
      NATIVE_USER_HOME="${existing_home}"
    fi
  fi
  run_as_root mkdir -p \
    "${NATIVE_USER_HOME}/.config/systemd/user" \
    "${PANEL_DATA_DIR}" \
    "${PANEL_LOG_DIR}" \
    "${PANEL_INSTANCES_DIR}" \
    "${PANEL_BACKUPS_DIR}" \
    "${PANEL_DATA_DIR}/runtime"
  run_as_root chown -R "${NATIVE_SERVICE_USER}:${NATIVE_SERVICE_GROUP}" \
    "${NATIVE_USER_HOME}" \
    "${PANEL_DATA_DIR}" \
    "${PANEL_LOG_DIR}"

  local native_uid
  native_uid="$(id -u "${NATIVE_SERVICE_USER}")"
  run_as_root loginctl enable-linger "${NATIVE_SERVICE_USER}"
  run_as_root systemctl start "user@${native_uid}.service"
}

verify_native_archive_paths() {
  local archive_path="$1"
  if tar -tzf "${archive_path}" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    return 1
  fi
  return 0
}

download_native_release_archive() {
  local archive_dest="$1"
  local checksum_dest="$2"
  local archive_filename="${NATIVE_RELEASE_NAME}.tar.gz"
  local checksum_filename="${archive_filename}.sha256"
  local source expected_sum actual_sum

  if [[ -n "${NATIVE_RELEASE_ARCHIVE}" ]]; then
    if [[ ! -f "${NATIVE_RELEASE_ARCHIVE}" ]]; then
      log_error "Configured Native archive does not exist: ${NATIVE_RELEASE_ARCHIVE}"
      return 1
    fi
    cp "${NATIVE_RELEASE_ARCHIVE}" "${archive_dest}"
    if [[ -f "${NATIVE_RELEASE_ARCHIVE}.sha256" ]]; then
      cp "${NATIVE_RELEASE_ARCHIVE}.sha256" "${checksum_dest}"
    elif [[ -n "${BSP_NATIVE_RELEASE_SHA256:-}" ]]; then
      printf '%s  %s\n' "${BSP_NATIVE_RELEASE_SHA256}" "${archive_filename}" > "${checksum_dest}"
    else
      log_error "Local Native archive requires a sibling .sha256 file or BSP_NATIVE_RELEASE_SHA256."
      return 1
    fi
  else
    if [[ -z "${NATIVE_RELEASE_MIRRORS}" ]]; then
      NATIVE_RELEASE_MIRRORS="$(build_github_url_variants "https://github.com/PMAT77/bubble-shark-panel/releases/download/${BSP_RELEASE_TAG}")"
      log_info "Native release mirrors: ${NATIVE_RELEASE_MIRRORS}"
    fi
    local raw_sources=()
    IFS=',' read -r -a raw_sources <<< "${NATIVE_RELEASE_MIRRORS}"
    for source in "${raw_sources[@]}"; do
      source="${source%/}"
      log_info "Trying Native Release source: ${source}"
      if curl -fL --progress-bar --retry 3 --retry-delay 3 --retry-all-errors \
        --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
        --max-time 600 \
        -o "${archive_dest}" \
        "${source}/${archive_filename}" \
        && curl -fL \
          --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
          --max-time "${REPO_DOWNLOAD_TIMEOUT_SECONDS}" \
          -o "${checksum_dest}" \
          "${source}/${checksum_filename}"; then
        break
      fi
      rm -f "${archive_dest}" "${checksum_dest}"
    done
  fi

  if [[ ! -s "${archive_dest}" || ! -s "${checksum_dest}" ]]; then
    log_error "Unable to download Native Release ${archive_filename} and its checksum."
    return 1
  fi
  expected_sum="$(awk 'NR == 1 { print $1 }' "${checksum_dest}")"
  actual_sum="$(sha256sum "${archive_dest}" | awk '{print $1}')"
  if [[ -z "${expected_sum}" || "${expected_sum}" != "${actual_sum}" ]]; then
    log_error "Native Release checksum mismatch: expected ${expected_sum:-missing}, got ${actual_sum}."
    return 1
  fi
  verify_native_archive_paths "${archive_dest}" || {
    log_error "Native Release contains an unsafe archive path."
    return 1
  }
}

install_native_release() {
  local temp_dir archive_path checksum_path extracted_root target_dir replaced_dir
  temp_dir="$(mktemp -d)"
  archive_path="${temp_dir}/${NATIVE_RELEASE_NAME}.tar.gz"
  checksum_path="${archive_path}.sha256"

  download_native_release_archive "${archive_path}" "${checksum_path}" || {
    rm -rf "${temp_dir}"
    abort "Native Release download failed. Verify the ${BSP_RELEASE_TAG} GitHub Release assets or set BSP_NATIVE_RELEASE_ARCHIVE."
  }
  tar -xzf "${archive_path}" -C "${temp_dir}"
  extracted_root="${temp_dir}/${NATIVE_RELEASE_NAME}"
  if [[ ! -x "${extracted_root}/bin/bubblesharkpanel" || ! -f "${extracted_root}/release.json" ]]; then
    rm -rf "${temp_dir}"
    abort "Native Release is incomplete: launcher or release.json is missing."
  fi

  target_dir="${NATIVE_RELEASE_ROOT}/${BSP_RELEASE_TAG}"
  run_as_root mkdir -p "${NATIVE_RELEASE_ROOT}"
  if [[ -L "${NATIVE_CURRENT_LINK}" ]]; then
    NATIVE_PREVIOUS_RELEASE="$(readlink -f "${NATIVE_CURRENT_LINK}" || true)"
  fi
  if run_as_root test -e "${target_dir}"; then
    # 只保留最近一份让位副本，反复重装不至于把磁盘堆满
    run_as_root find "${NATIVE_RELEASE_ROOT}" -maxdepth 1 -type d -name "${BSP_RELEASE_TAG}.replaced.*" -exec rm -rf {} + 2>/dev/null || true
    replaced_dir="${target_dir}.replaced.$(date +%Y%m%d%H%M%S)"
    run_as_root mv "${target_dir}" "${replaced_dir}"
    # 同版本重装时 previous 与 target 是同一个路径，而该路径的内容刚被挪到 replaced_dir。
    # 不把它改指 replaced_dir 的话，健康检查失败时的「切回旧版本」会切回本次的新内容。
    if [[ "${NATIVE_PREVIOUS_RELEASE}" == "${target_dir}" ]]; then
      NATIVE_PREVIOUS_RELEASE="${replaced_dir}"
    fi
  fi
  run_as_root mv "${extracted_root}" "${target_dir}"
  run_as_root chown -R root:"${NATIVE_SERVICE_GROUP}" "${target_dir}"
  run_as_root chmod -R a-w "${target_dir}"
  run_as_root chmod 0755 "${target_dir}/bin/bubblesharkpanel"
  run_as_root ln -sfn "${target_dir}" "${NATIVE_CURRENT_LINK}.new"
  run_as_root mv -Tf "${NATIVE_CURRENT_LINK}.new" "${NATIVE_CURRENT_LINK}"
  # 升级/重装换了 current 链接，但已在运行的服务进程仍指向旧代码：deploy_native_panel
  # 必须显式重启一次，否则「升级完还是旧版本」且健康检查照样通过。
  if [[ -n "${NATIVE_PREVIOUS_RELEASE}" && "${NATIVE_PREVIOUS_RELEASE}" != "${target_dir}" ]]; then
    NATIVE_RELEASE_REPLACED=1
  fi
  rm -rf "${temp_dir}"
}

install_native_steamcmd() {
  local temp_archive
  if run_as_root test -x "${NATIVE_STEAMCMD_PATH}"; then
    log_info "Native SteamCMD already installed: ${NATIVE_STEAMCMD_PATH}"
    return
  fi
  temp_archive="$(mktemp)"
  if ! run_with_retry "download Native SteamCMD" curl -fL \
    --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
    --max-time 600 \
    -o "${temp_archive}" \
    "${NATIVE_STEAMCMD_URL}"; then
    rm -f "${temp_archive}"
    abort "SteamCMD download failed: ${NATIVE_STEAMCMD_URL}"
  fi
  run_as_root mkdir -p "${NATIVE_STEAMCMD_DIR}"
  run_as_root tar -xzf "${temp_archive}" -C "${NATIVE_STEAMCMD_DIR}"
  rm -f "${temp_archive}"
  run_as_root chown -R "${NATIVE_SERVICE_USER}:${NATIVE_SERVICE_GROUP}" "${NATIVE_STEAMCMD_DIR}"
  run_as_root chmod 0755 "${NATIVE_STEAMCMD_PATH}"
}

prepare_native_panel_env() {
  local native_uid steamcmd_attempts existing_port existing_public_url is_upgrade
  native_uid="$(id -u "${NATIVE_SERVICE_USER}")"
  steamcmd_attempts=5
  if [[ "${RESOLVED_NETWORK_PROFILE}" == "cn" ]]; then
    steamcmd_attempts=8
  fi
  run_as_root mkdir -p "${PANEL_INSTALL_DIR}"
  # is_upgrade 只在 Docker 分支的 prepare_panel_files 里声明过，Native 分支漏了它；
  # 而下面要用它决定「是否追加内存档位预设」。set -u 下引用未定义变量即致命退出，
  # Native 安装会 100% 死在 configuration 阶段，必须显式初始化。
  is_upgrade=0
  if try_as_root test -f "${PANEL_ENV_FILE}"; then
    is_upgrade=1
    existing_port="$(read_env_value "${PANEL_ENV_FILE}" "SERVER_PORT")"
    existing_public_url="$(read_env_value "${PANEL_ENV_FILE}" "PANEL_PUBLIC_URL")"
    if [[ "${existing_port}" =~ ^[0-9]+$ ]]; then
      PANEL_PORT="${existing_port}"
    fi
    detect_host_ip
    resolve_panel_access_urls
    reconcile_existing_public_url "${existing_public_url:-}"
    run_as_root cp -p "${PANEL_ENV_FILE}" "${PANEL_ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    upsert_env_values "${PANEL_ENV_FILE}" \
      "NODE_ENV=production" \
      "BSP_EDITION=community" \
      "BSP_RESOURCE_PREFIX=${BSP_RESOURCE_PREFIX:-bsp}" \
      "BSP_PANEL_DB_FILENAME=${PANEL_DB_FILENAME}" \
      "BSP_PANEL_CONTAINER_NAME=${BSP_PANEL_CONTAINER_NAME:-bubblesharkpanel-panel}" \
      "BSP_NATIVE_SERVICE=${PANEL_NATIVE_SERVICE}" \
      "BSP_RUNTIME_MODE=native" \
      "BSP_INSTANCES_ROOT=${PANEL_INSTANCES_DIR}" \
      "BSP_BACKUPS_ROOT=${PANEL_BACKUPS_DIR}" \
      "BSP_NATIVE_RUNTIME_DIR=${BSP_NATIVE_RUNTIME_DIR:-${PANEL_DATA_DIR}/runtime}" \
      "BSP_NATIVE_STEAMCMD_PATH=${NATIVE_STEAMCMD_PATH}" \
      "BSP_NATIVE_SYSTEMD_UNIT_DIR=${NATIVE_USER_HOME}/.config/systemd/user" \
      "BSP_NATIVE_USER=${NATIVE_SERVICE_USER}" \
      "BSP_NATIVE_UPDATE_DIR=${NATIVE_UPDATE_DIR}" \
      "BSP_GITHUB_REPO=PMAT77/bubble-shark-panel" \
      "BSP_RELEASE_VERSION=${BSP_RELEASE_TAG}"
    log_info "Preserved existing Native panel.env and updated release/runtime keys."
  else
    detect_host_ip
    resolve_panel_access_urls
    generate_admin_credentials
    # 用 printf 逐行写入再以 root 原子落盘：环境变量传入的凭证含 $、反引号、引号时
    # 不会被 shell 展开（旧无引号 heredoc 会破坏凭证甚至注入任意行）。
    local panel_env_tmp
    panel_env_tmp="$(mktemp)"
    {
      printf '%s\n' \
        "NODE_ENV=production" \
        "SERVER_HOST=0.0.0.0" \
        "SERVER_PORT=${PANEL_PORT}" \
        "DB_PATH=${PANEL_DATA_DIR}/${PANEL_DB_FILENAME}" \
        "SERVER_LOG_DIR=${PANEL_LOG_DIR}" \
        "# PANEL_PUBLIC_URL：$(panel_public_ip_source_label "${PANEL_PUBLIC_IP_SOURCE}")；换域名/反向代理请直接编辑本行" \
        "PANEL_PUBLIC_URL=${PANEL_ACCESS_URL}" \
        "ADMIN_USERNAME=${ADMIN_USERNAME}" \
        "ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
        "FORCE_PASSWORD_CHANGE=1" \
        "BSP_EDITION=community" \
      "BSP_RESOURCE_PREFIX=${BSP_RESOURCE_PREFIX:-bsp}" \
      "BSP_PANEL_DB_FILENAME=${PANEL_DB_FILENAME}" \
      "BSP_PANEL_CONTAINER_NAME=${BSP_PANEL_CONTAINER_NAME:-bubblesharkpanel-panel}" \
      "BSP_NATIVE_SERVICE=${PANEL_NATIVE_SERVICE}" \
        "BSP_RUNTIME_MODE=native" \
        "BSP_INSTANCES_ROOT=${PANEL_INSTANCES_DIR}" \
        "BSP_BACKUPS_ROOT=${PANEL_BACKUPS_DIR}" \
        "BSP_NATIVE_RUNTIME_DIR=${BSP_NATIVE_RUNTIME_DIR:-${PANEL_DATA_DIR}/runtime}" \
        "BSP_NATIVE_STEAMCMD_PATH=${NATIVE_STEAMCMD_PATH}" \
        "BSP_NATIVE_SYSTEMD_UNIT_DIR=${NATIVE_USER_HOME}/.config/systemd/user" \
        "BSP_NATIVE_USER=${NATIVE_SERVICE_USER}" \
        "BSP_NATIVE_UPDATE_DIR=${NATIVE_UPDATE_DIR}" \
        "BSP_STEAMCMD_INSTALL_MAX_ATTEMPTS=${steamcmd_attempts}" \
        "BSP_GITHUB_REPO=PMAT77/bubble-shark-panel" \
        "BSP_RELEASE_VERSION=${BSP_RELEASE_TAG}" \
        "TZ=UTC"
    } > "${panel_env_tmp}"
    run_as_root install -m 0640 -o root -g "${NATIVE_SERVICE_GROUP}" "${panel_env_tmp}" "${PANEL_ENV_FILE}"
    rm -f "${panel_env_tmp}"
  fi

  # 内存档位预设此前只在 Docker 分支合并，Native 于是开箱没有任何 DST 内存上限，
  # 与「资源限制交给 systemd」的承诺不符。两种模式的档位口径必须一致。
  # Docker 分支在 prepare_panel_files 里已经 sync 过，Native 此前没有：单文件安装器
  # （Release 附件 / 管道执行）身边没有仓库副本，append_panel_env_preset 只会打一条
  # "Preset file not found" 就跳过，4 GiB 机器于是拿不到任何内存档位。
  sync_panel_env_presets
  if [[ "${is_upgrade}" -eq 0 ]]; then
    local host_mem_total_mb preset_name
    host_mem_total_mb="$(read_host_mem_total_mb)"
    preset_name="$(resolve_panel_env_preset_name "${host_mem_total_mb}")"
    append_panel_env_preset "${preset_name}"
  fi

  run_as_root bash -c "cat > \"${NATIVE_SYSTEMD_UNIT}\" <<EOF
[Unit]
Description=BubbleSharkPanel (Native)
After=network-online.target user@${native_uid}.service
Wants=network-online.target
Requires=user@${native_uid}.service

[Service]
Type=simple
User=${NATIVE_SERVICE_USER}
Group=${NATIVE_SERVICE_GROUP}
WorkingDirectory=${NATIVE_CURRENT_LINK}
EnvironmentFile=${PANEL_ENV_FILE}
Environment=HOME=${NATIVE_USER_HOME}
Environment=XDG_RUNTIME_DIR=/run/user/${native_uid}
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${native_uid}/bus
ExecStart=${NATIVE_CURRENT_LINK}/bin/bubblesharkpanel
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${PANEL_DATA_DIR} ${PANEL_LOG_DIR} ${NATIVE_USER_HOME} ${PANEL_INSTALL_DIR}/runtime

[Install]
WantedBy=multi-user.target
EOF"
  run_as_root systemctl daemon-reload
}

# 避免将面板绑定到已被占用的宿主机端口。
check_port_conflict() {
  local existing_mode
  if existing_mode="$(resolve_existing_install_mode)" && [[ "${existing_mode}" == "${RESOLVED_INSTALL_MODE}" ]]; then
    log_info "Skipping port-conflict rejection for the existing ${existing_mode} installation."
    return
  fi
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn "( sport = :${PANEL_PORT} )" | awk 'NR > 1 { found = 1 } END { exit(found ? 0 : 1) }'; then
      abort "Port ${PANEL_PORT} is already in use. Set PANEL_PORT to an unused port and retry."
    fi
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"${PANEL_PORT}" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
      abort "Port ${PANEL_PORT} is already in use. Set PANEL_PORT to an unused port and retry."
    fi
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    if netstat -ltn 2>/dev/null | awk -v port=":${PANEL_PORT}" '$4 ~ port"$" { found = 1 } END { exit(found ? 0 : 1) }'; then
      abort "Port ${PANEL_PORT} is already in use. Set PANEL_PORT to an unused port and retry."
    fi
    return
  fi

  log_warn "Port conflict check skipped: ss/lsof/netstat not found."
}

# 优先使用现有防火墙工具开放端口；若不可用则给出手动提示。
open_firewall_port() {
  local rule_desc
  rule_desc="tcp/${PANEL_PORT}"

  if command -v ufw >/dev/null 2>&1; then
    if ! run_as_root ufw status >/dev/null 2>&1; then
      log_warn "ufw detected but not active/initialized. Skipping automatic firewall rule."
      return
    fi
    log_info "Configuring firewall via ufw: allow ${rule_desc}"
    if run_as_root ufw allow "${PANEL_PORT}/tcp" >/dev/null; then
      log_warn "Firewall note: panel port ${PANEL_PORT} is exposed externally. Restrict source IPs if needed."
    else
      log_warn "Failed to apply ufw rule for ${rule_desc}. Please allow it manually."
    fi
    return
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    if run_as_root systemctl is-active --quiet firewalld; then
      log_info "Configuring firewall via firewalld: allow ${rule_desc}"
      if run_as_root firewall-cmd --add-port="${PANEL_PORT}/tcp" --permanent >/dev/null && run_as_root firewall-cmd --reload >/dev/null; then
        log_warn "Firewall note: panel port ${PANEL_PORT} is exposed externally. Restrict source IPs if needed."
      else
        log_warn "Failed to apply firewalld rule for ${rule_desc}. Please allow it manually."
      fi
      return
    fi
    log_warn "firewall-cmd detected but firewalld is not active. Skipping automatic firewall rule."
    return
  fi

  log_warn "No ufw/firewalld detected. Please open tcp/${PANEL_PORT} manually."
}

# 可选：开放 DST 默认 UDP 游戏端口（主世界 + 洞穴，各含游戏 / Steam 认证 / Steam 主服务器）
# 安装时无法预知用户之后是否开启洞穴，因此一并放行洞穴的 3 个端口（UDP 放行无副作用）
open_firewall_dst_ports() {
  local ports=(
    "${DST_GAME_PORT}" "${DST_AUTH_PORT}" "${DST_MASTER_PORT}"
    "${DST_CAVES_GAME_PORT}" "${DST_CAVES_AUTH_PORT}" "${DST_CAVES_MASTER_PORT}"
  )
  local port rule_desc

  for port in "${ports[@]}"; do
    rule_desc="udp/${port}"
    if command -v ufw >/dev/null 2>&1; then
      log_info "Configuring firewall via ufw: allow ${rule_desc}"
      run_as_root ufw allow "${port}/udp" >/dev/null || true
      continue
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
      log_info "Configuring firewall via firewalld: allow ${rule_desc}"
      run_as_root firewall-cmd --add-port="${port}/udp" --permanent >/dev/null || true
      continue
    fi
    log_warn "No ufw/firewalld detected. Please open ${rule_desc} manually (and cloud security group)."
    return
  done

  if command -v firewall-cmd >/dev/null 2>&1; then
    run_as_root firewall-cmd --reload >/dev/null || true
  fi
  log_warn "Firewall note: DST UDP ports ${DST_GAME_PORT}/${DST_AUTH_PORT}/${DST_MASTER_PORT} (master) and ${DST_CAVES_GAME_PORT}/${DST_CAVES_AUTH_PORT}/${DST_CAVES_MASTER_PORT} (caves) opened. Adjust if you changed server.ini ports."
}

print_usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  --mode MODE         Deployment mode: auto, docker or native
  --network PROFILE   Network profile: auto, cn or global
  --check            Print the preflight report and exit without changing the system
  --open-panel-port  Open panel TCP port (${PANEL_PORT}) via ufw/firewalld
  --open-dst-ports   Open default DST UDP ports for master (${DST_GAME_PORT}, ${DST_AUTH_PORT}, ${DST_MASTER_PORT}) and caves (${DST_CAVES_GAME_PORT}, ${DST_CAVES_AUTH_PORT}, ${DST_CAVES_MASTER_PORT}) via ufw/firewalld
  --no-swap          Do not create a swapfile on small-RAM hosts (same as BSP_SWAP_ON_INSTALL=0)
  -h, --help         Show this help

Environment (optional):
  BSP_INSTALL_MODE=MODE          Same as --mode
  BSP_NETWORK_PROFILE=PROFILE    Same as --network
  PANEL_PUBLIC_URL=URL          Explicit public panel URL (e.g. https://bsp.example.com); skips IP probing
  PANEL_HOST=IP                 Explicit panel host/IP; also skips IP probing
  BSP_PANEL_AUTO_PUBLIC_IP=0    Disable public IP probing (default: cloud metadata, then outbound IP echo)
  BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS=3  Total budget for the public IP probing above
  INSTALL_STEAMCMD_IMAGE=0      Skip SteamCMD pre-pull (default: pre-pull so the panel is ready to create instances)
  PANEL_IMAGE=REF               Full unified image reference (tag or digest); overrides the GHCR default
  BSP_GAME_DST_IMAGE=REF        Kept for compatibility; defaults to PANEL_IMAGE (v0.2.0 unified image)
  BSP_STEAMCMD_IMAGE=REF        Kept for compatibility; defaults to PANEL_IMAGE (v0.2.0 unified image)
  BSP_GITHUB_PROXY=URL          Force one GitHub accelerator (e.g. https://gh-proxy.com/)
  BSP_IMAGE_SOURCE=MODE         Runtime image source: auto (default), offline (always use the
                                Release image archive), native (always pull from GHCR)
  BSP_FORCE_IMAGE_PULL=1        Pull even when the image already exists locally
  HIDE_ADMIN_PASSWORD=1         Do not print the initial admin password in the install summary
  DOCKER_PULL_STALL_SECONDS=90  Give up a GHCR pull after this many seconds without progress
  PANEL_HEALTHCHECK_TIMEOUT_SECONDS=90  Maximum wait for panel /health after startup
  PANEL_HEALTHCHECK_INTERVAL_SECONDS=3  Panel /health polling interval
  USE_CN_DEBIAN_MIRROR=1        Enable CN Debian/Ubuntu mirror
  BSP_NATIVE_RELEASE_ARCHIVE=PATH  Install a local Native Release archive
  BSP_NATIVE_UPDATE_DIR=PATH    Native panel-update exchange directory (default: <data dir>/panel-update)
  BSP_SWAP_ON_INSTALL=0         Do not create a swapfile automatically on small-RAM hosts (default: 1)
  BSP_SWAP_SIZE=4G              Swapfile size when one is created (default: 2G, or 4G below ${HOST_MEMORY_WARN_MIN_MB} MB)
  BSP_SWAP_FILE=PATH            Swapfile path (default: /swapfile-bsp)
  BSP_SWAP_AUTO_THRESHOLD_MB=5120  Total RAM below which the swapfile is created (default: ${HOST_MEMORY_TIER_SMALL_MAX_MB})
  STRICT_INSTALLER_ASSET_CHECKSUM=0  Skip embedded checksum verification (not recommended)
  v0.2.0 unified image: one docker pull provides the panel, DST runtime libraries and SteamCMD.

Full parameter and variable reference: docs/reference.md
EOF
}

# 私有/不可对外使用的 IPv4 字面量（含回环、链路本地与 CGNAT 100.64/10）；非 IPv4 字面量返回 1。
is_private_ipv4() {
  local ip="$1" parts a b c d
  if [[ ! "${ip}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    return 1
  fi
  local IFS='.'
  read -r -a parts <<< "${ip}"
  a="${parts[0]}"
  b="${parts[1]}"
  c="${parts[2]}"
  d="${parts[3]}"
  if (( a > 255 || b > 255 || c > 255 || d > 255 )); then
    return 1
  fi
  if (( a == 0 || a == 10 || a == 127 )); then
    return 0
  fi
  if (( a == 169 && b == 254 )); then
    return 0
  fi
  if (( a == 172 && b >= 16 && b <= 31 )); then
    return 0
  fi
  if (( a == 192 && b == 168 )); then
    return 0
  fi
  if (( a == 100 && b >= 64 && b <= 127 )); then
    return 0
  fi
  return 1
}

# 可直接对外使用的 IPv4 字面量：格式与各段合法，且不属于私有网段。
is_public_ipv4() {
  local ip="$1" parts a b c d
  if [[ ! "${ip}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    return 1
  fi
  local IFS='.'
  read -r -a parts <<< "${ip}"
  a="${parts[0]}"
  b="${parts[1]}"
  c="${parts[2]}"
  d="${parts[3]}"
  if (( a > 255 || b > 255 || c > 255 || d > 255 )); then
    return 1
  fi
  if is_private_ipv4 "${ip}"; then
    return 1
  fi
  return 0
}

# 布尔环境变量是否为「关闭」；空值视为未设置，保持调用方默认行为。
env_flag_is_off() {
  local raw="${1:-}"
  raw="${raw,,}"
  case "${raw}" in
    0|false|off|no) return 0 ;;
  esac
  return 1
}

# 从 URL 中取出主机名（只处理 IPv4 与域名，不支持 IPv6 字面量）。
url_host() {
  local url="$1" host
  host="${url#*://}"
  host="${host%%/*}"
  host="${host%%:*}"
  printf '%s' "${host}"
}

# 主机名是否只能在内网使用（空值、localhost、私有 IPv4 字面量）；域名按「对外」处理。
is_private_host() {
  local host="$1"
  case "${host}" in
    ''|localhost|localhost.*|127.0.0.1) return 0 ;;
  esac
  if is_private_ipv4 "${host}"; then
    return 0
  fi
  return 1
}

# 对外地址来源的中文标签（摘要与 panel.env 注释共用）。
panel_public_ip_source_label() {
  case "$1" in
    user) printf '%s' "按 PANEL_PUBLIC_URL/PANEL_HOST 指定" ;;
    interface) printf '%s' "本机网卡公网地址" ;;
    cloud_metadata) printf '%s' "云平台元数据探测" ;;
    ip_echo) printf '%s' "出站 IP 探测" ;;
    *) printf '%s' "本机内网地址（未能探测到公网地址）" ;;
  esac
}

# 未提供 PANEL_HOST 时，自动探测主机地址。
# 默认路由出口优先：多网卡/NAT 机器上 hostname -I 的第一项常属于 docker0 等虚拟网卡，
# 直接取它会把面板地址写成容器网段地址，用户从任何地方都连不上。
detect_host_ip() {
  if [[ -n "${PANEL_HOST}" ]]; then
    PANEL_HOST_SOURCE="user"
    return
  fi

  if command -v ip >/dev/null 2>&1; then
    PANEL_HOST="$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')" || true
  fi
  if [[ -z "${PANEL_HOST}" ]]; then
    PANEL_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -z "${PANEL_HOST}" ]]; then
    PANEL_HOST="127.0.0.1"
  fi
  PANEL_HOST_SOURCE="interface"
}

# 并发探测一组「返回纯文本 IPv4」的端点，按数组顺序返回第一个可用的公网地址。
# 并发而非串行：最坏耗时等于单个端点超时，而不是各端点超时之和。
probe_public_ipv4_from_urls() {
  local timeout_seconds="$1"
  shift
  local urls=("$@")
  local tmp_dir index url candidate
  local -a pids=()

  tmp_dir="$(mktemp -d)"
  index=0
  for url in "${urls[@]}"; do
    index=$((index + 1))
    # --noproxy '*'：元数据端点必须直连，走代理只会拿到代理的出口地址。
    curl --noproxy '*' --silent --show-error --max-time "${timeout_seconds}" "${url}" \
      > "${tmp_dir}/${index}" 2>/dev/null &
    pids+=("$!")
  done
  # 只等自己拉起的探测：等待全部后台作业会把调用方的其它作业也一起拖住。
  if (( ${#pids[@]} > 0 )); then
    wait "${pids[@]}" || true
  fi

  for ((index = 1; index <= ${#urls[@]}; index++)); do
    candidate="$(head -n 1 "${tmp_dir}/${index}" 2>/dev/null | tr -d '[:space:]')" || true
    if is_public_ipv4 "${candidate}"; then
      rm -rf "${tmp_dir}"
      printf '%s' "${candidate}"
      return 0
    fi
  done

  rm -rf "${tmp_dir}"
  return 1
}

# 探测对外可用的 IPv4；命中时设置 PANEL_PUBLIC_IP_SOURCE 与 PANEL_DETECTED_PUBLIC_IP 并返回 0。
detect_public_access_ip() {
  local budget="${BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS}"
  local metadata_timeout=1
  local echo_timeout=2
  local deadline detected

  if [[ ! "${budget}" =~ ^[0-9]+$ ]] || (( budget <= 0 )); then
    log_warn "Ignoring invalid BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS=${BSP_PANEL_PUBLIC_IP_BUDGET_SECONDS}; using 3s."
    budget=3
  fi
  if (( echo_timeout > budget )); then
    echo_timeout="${budget}"
  fi
  deadline=$((SECONDS + budget))

  if detected="$(probe_public_ipv4_from_urls "${metadata_timeout}" "${PANEL_CLOUD_METADATA_URLS[@]}")"; then
    PANEL_PUBLIC_IP_SOURCE="cloud_metadata"
    PANEL_DETECTED_PUBLIC_IP="${detected}"
    return 0
  fi
  if (( SECONDS >= deadline )); then
    return 1
  fi
  if detected="$(probe_public_ipv4_from_urls "${echo_timeout}" "${PANEL_PUBLIC_IP_ECHO_URLS[@]}")"; then
    PANEL_PUBLIC_IP_SOURCE="ip_echo"
    PANEL_DETECTED_PUBLIC_IP="${detected}"
    return 0
  fi
  return 1
}

# 解析对外访问地址与本机地址。
# 优先级：显式 PANEL_PUBLIC_URL/PANEL_HOST > 网卡公网地址 > 云元数据 > 出站回显 > 本机地址。
# PANEL_ACCESS_URL 落进 panel.env；PANEL_LAN_URL 只用于摘要，让内网用户也知道怎么连。
resolve_panel_access_urls() {
  PANEL_LAN_URL="${PANEL_PROTOCOL}://${PANEL_HOST}:${PANEL_PORT}"

  if [[ -n "${PANEL_PUBLIC_URL_OVERRIDE}" ]]; then
    PANEL_ACCESS_URL="${PANEL_PUBLIC_URL_OVERRIDE}"
    PANEL_PUBLIC_IP_SOURCE="user"
    return
  fi
  if [[ "${PANEL_HOST_SOURCE}" == "user" ]]; then
    PANEL_ACCESS_URL="${PANEL_LAN_URL}"
    PANEL_PUBLIC_IP_SOURCE="user"
    return
  fi
  # 网卡上本来就是公网地址（直挂公网的云主机/独立服务器）：无需任何探测。
  if is_public_ipv4 "${PANEL_HOST}"; then
    PANEL_ACCESS_URL="${PANEL_LAN_URL}"
    PANEL_PUBLIC_IP_SOURCE="interface"
    return
  fi
  if env_flag_is_off "${BSP_PANEL_AUTO_PUBLIC_IP}"; then
    PANEL_ACCESS_URL="${PANEL_LAN_URL}"
    PANEL_PUBLIC_IP_SOURCE="lan"
    return
  fi

  PANEL_DETECTED_PUBLIC_IP=""
  if detect_public_access_ip; then
    PANEL_ACCESS_URL="${PANEL_PROTOCOL}://${PANEL_DETECTED_PUBLIC_IP}:${PANEL_PORT}"
    return
  fi

  # 探测不到就如实标成本机内网地址，由摘要给出公网访问指引，
  # 不再打印一个裸地址冒充「面板地址」。
  PANEL_ACCESS_URL="${PANEL_LAN_URL}"
  PANEL_PUBLIC_IP_SOURCE="lan"
}

# 升级已有安装时决定 PANEL_PUBLIC_URL 保留旧值还是改用本次解析值。
# 用户设置过的地址（域名/反代/公网 IP）一律保留；只有「旧值只是内网地址、本次又解析到对外地址」
# 才纠正——否则那台机器的 panel.env 会永远停在会被误读成「面板不可访问」的内网地址上。
# 注意：本函数直接更新 PANEL_ACCESS_URL 而不是用 printf 返回。它内部会打日志，
# 若改用命令替换取值，日志会被一起捕获进 URL。
reconcile_existing_public_url() {
  local existing="${1:-}"
  if [[ -z "${existing}" ]]; then
    return
  fi
  case "${PANEL_PUBLIC_IP_SOURCE}" in
    user)
      # resolve_panel_access_urls 已按用户显式指定填好。
      return
      ;;
    lan|interface)
      PANEL_ACCESS_URL="${existing}"
      return
      ;;
  esac
  if is_private_host "$(url_host "${existing}")"; then
    log_info "Recorded PANEL_PUBLIC_URL (${existing}) is a LAN-only address; updating it to ${PANEL_ACCESS_URL}."
    return
  fi
  PANEL_ACCESS_URL="${existing}"
}

# 调用方未提供管理员密码时，自动生成一次性密码。
generate_admin_credentials() {
  if [[ -z "${ADMIN_PASSWORD}" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)"
    else
      # /dev/urandom 是始终存在的内核熵源；旧回退用秒级时间戳（约 30 bit 熵）可被离线枚举。
      ADMIN_PASSWORD="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    fi
  fi
}

# 读取宿主机总内存（MiB），失败时返回 0。
read_host_mem_total_mb() {
  awk '/^MemTotal:/ { printf "%d", int($2 / 1024); exit }' /proc/meminfo 2>/dev/null || echo 0
}

# 按总内存解析 panel.env 预设名（auto 时自动分档）。
resolve_panel_env_preset_name() {
  local total_mb="$1"
  local preset="${BSP_PANEL_ENV_PRESET}"

  case "${preset}" in
    none|off|disable)
      printf '%s' "none"
      return
      ;;
    small|medium|large)
      printf '%s' "${preset}"
      return
      ;;
    auto|"")
      ;;
    *)
      log_warn "Unknown BSP_PANEL_ENV_PRESET=${preset}, fallback to auto."
      ;;
  esac

  if [[ "${total_mb}" -lt "${HOST_MEMORY_TIER_SMALL_MAX_MB}" ]]; then
    printf '%s' "small"
  elif [[ "${total_mb}" -lt "${HOST_MEMORY_TIER_MEDIUM_MAX_MB}" ]]; then
    printf '%s' "medium"
  else
    printf '%s' "large"
  fi
}

# 安装前内存档位提示（不阻断安装）。
warn_host_memory_tier() {
  local total_mb="$1"
  local preset_name tier_label

  if [[ "${total_mb}" -le 0 ]]; then
    log_warn "Cannot read host MemTotal; skip memory tier warning."
    return
  fi

  preset_name="$(resolve_panel_env_preset_name "${total_mb}")"
  case "${preset_name}" in
    small) tier_label="小内存（约 4 GiB）" ;;
    medium) tier_label="中等（约 6 GiB）" ;;
    large) tier_label="充足（8 GiB 及以上）" ;;
    *) tier_label="未应用预设" ;;
  esac

  log_info "Host memory total: ${total_mb} MB (tier: ${tier_label}, preset: ${preset_name})"

  if [[ "${total_mb}" -lt "${HOST_MEMORY_WARN_MIN_MB}" ]]; then
    log_warn "Host RAM is below ~4 GiB. Recommended: single surface shard, few mods, avoid caves. See docs/MEMORY.md."
    log_warn "Single instance + caves + many mods may OOM. Consider upgrading to 6-8 GiB, use preset: config/panel.env.presets/small.env, and run: bsp setup-swap"
    write_status "preflight" "warn" "Low host RAM ${total_mb} MB; see docs/MEMORY.md and bsp setup-swap"
  elif [[ "${total_mb}" -lt "${HOST_MEMORY_TIER_SMALL_MAX_MB}" ]]; then
    log_warn "Host RAM tier is small (<5 GiB). Caves and heavy mod sets increase OOM risk. See docs/MEMORY.md; consider: bsp setup-swap"
    write_status "preflight" "warn" "Host RAM tier small (${total_mb} MB)"
  fi
}

# ---------- 安装时自动配置 swap（小内存机） ----------
# 创建缓存区需要 root，而面板在 Docker 模式是非特权容器、在 Native 模式以 bsp 用户运行 systemd，
# 面板自己做不到这件事（这是有意的安全设计）。安装器本来就是 root，顺手做掉能消掉一整类
# 「实例显示运行中、大厅却搜不到」的隐性故障。

# 是否已有生效中的 swap：不区分来源（发行版默认分区、云镜像自带、或安装器自己创建的）。
has_active_swap() {
  command -v swapon >/dev/null 2>&1 || return 1
  swapon --show=NAME --noheadings 2>/dev/null | grep -q .
}

# 自动创建的 swapfile 大小（MiB）：4 GiB 类机器给 2 GiB 即可把加载尖峰落下去；
# MemTotal 更小的机器（约 3.7 GiB 及以下）多给一档，否则尖峰仍可能溢出。
resolve_auto_swap_size_mb() {
  local total_mb="$1"
  if [[ "${total_mb}" -lt "${HOST_MEMORY_WARN_MIN_MB}" ]]; then
    printf '%s' "4096"
  else
    printf '%s' "2048"
  fi
}

# 真正执行创建：优先复用仓库里的 bsp.sh（与 bsp setup-swap 完全同一份实现，避免两处漂移），
# bsp.sh 不在本地时退回已部署的 bsp CLI（curl | bash 安装路线）。
invoke_swap_setup() {
  local size_mb="$1"
  local script_dir candidate

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="${script_dir}/bsp.sh"
  if [[ -f "${candidate}" ]]; then
    (
      BSP_BSP_LIB_ONLY=1
      BSP_SWAP_SIZE="${size_mb}M"
      # shellcheck source=scripts/bsp.sh
      source "${candidate}"
      cmd_setup_swap
    )
    return $?
  fi

  if command -v bsp >/dev/null 2>&1; then
    BSP_SWAP_SIZE="${size_mb}M" bsp setup-swap
    return $?
  fi

  log_warn "bsp.sh (or the bsp CLI) is unavailable; skipping the automatic swapfile."
  return 1
}

# 小内存且当前没有缓存区时，创建 swapfile 并保证重启后仍然生效。
ensure_small_host_swap() {
  local total_mb size_mb swap_file free_disk_mb

  if [[ "${BSP_SWAP_ON_INSTALL}" == "0" || "${BSP_SWAP_ON_INSTALL}" == "off" || "${BSP_SWAP_ON_INSTALL}" == "false" ]]; then
    AUTO_SWAP_STATE="skipped"
    AUTO_SWAP_SKIPPED_REASON="disabled"
    log_info "Automatic swap setup disabled (BSP_SWAP_ON_INSTALL=${BSP_SWAP_ON_INSTALL})."
    return 0
  fi

  total_mb="$(read_host_mem_total_mb)"
  if [[ -z "${total_mb}" || "${total_mb}" -le 0 ]]; then
    AUTO_SWAP_STATE="skipped"
    AUTO_SWAP_SKIPPED_REASON="unknown-memory"
    log_warn "Cannot read host MemTotal; skipping the automatic swapfile."
    return 0
  fi

  if [[ "${total_mb}" -ge "${BSP_SWAP_AUTO_THRESHOLD_MB}" ]]; then
    AUTO_SWAP_STATE="skipped"
    AUTO_SWAP_SKIPPED_REASON="memory-ok"
    log_info "Host RAM ${total_mb} MB >= ${BSP_SWAP_AUTO_THRESHOLD_MB} MB; no swapfile needed."
    return 0
  fi

  if has_active_swap; then
    AUTO_SWAP_STATE="active"
    log_info "Host RAM ${total_mb} MB, but swap is already active; leaving it untouched."
    swapon --show 2>/dev/null || true
    return 0
  fi

  size_mb="$(resolve_auto_swap_size_mb "${total_mb}")"
  AUTO_SWAP_TARGET_MB="${size_mb}"
  swap_file="${BSP_SWAP_FILE:-/swapfile-bsp}"

  # 没地方放 swapfile 时不要写出一个半途而废的配置：明确告警，让用户自行决定。
  free_disk_mb="$(df -Pm / | awk 'NR == 2 { print $4 }')"
  if [[ -n "${free_disk_mb}" && "${free_disk_mb}" =~ ^[0-9]+$ ]] && [[ "${free_disk_mb}" -lt $((size_mb + 512)) ]]; then
    AUTO_SWAP_STATE="skipped"
    AUTO_SWAP_SKIPPED_REASON="disk"
    log_warn "Root filesystem has ${free_disk_mb} MB free; a ${size_mb} MiB swapfile does not fit. Skipping automatic swap."
    log_warn "Free some space and run: sudo bsp setup-swap"
    return 0
  fi

  # 非 root 环境下 require_root 会直接 exit，这里先自行判断，避免把安装流程带走。
  if [[ "$(id -u)" -ne 0 ]]; then
    AUTO_SWAP_STATE="skipped"
    AUTO_SWAP_SKIPPED_REASON="not-root"
    log_warn "Not running as root; skipping the automatic swapfile. Run: sudo bsp setup-swap"
    return 0
  fi

  log_info "Host RAM ${total_mb} MB and no swap detected; creating a ${size_mb} MiB swapfile at ${swap_file}..."
  if invoke_swap_setup "${size_mb}" && has_active_swap; then
    AUTO_SWAP_STATE="created"
    log_info "Automatic swapfile ready (${size_mb} MiB). It survives reboots via /etc/fstab."
    return 0
  fi

  AUTO_SWAP_STATE="failed"
  log_warn "Automatic swapfile setup failed; the installer continues. Run manually: sudo bsp setup-swap"
  return 0
}

# 同步 panel.env 预设到安装目录（优先本地仓库，其次脚本内置，最后镜像池下载）。
sync_panel_env_presets() {
  local script_dir src_dir dest_dir item
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  src_dir="${script_dir}/../config/panel.env.presets"
  dest_dir="${PANEL_INSTALL_DIR}/config/panel.env.presets"

  run_as_root mkdir -p "${dest_dir}"
  for item in small.env medium.env large.env README.md; do
    if [[ -f "${src_dir}/${item}" ]]; then
      run_as_root cp "${src_dir}/${item}" "${dest_dir}/${item}"
    elif write_builtin_panel_env_preset_asset "${item}" "${dest_dir}/${item}"; then
      log_info "Synced panel.env preset from built-in asset: ${item}"
    elif download_installer_asset "config/panel.env.presets/${item}" "${dest_dir}/${item}"; then
      log_info "Downloaded panel.env preset asset: ${item}"
    else
      log_warn "Could not sync preset asset: ${item}"
    fi
  done
}

# 将 config/panel.env.presets/<name>.env 追加到 panel.env（若存在）。
append_panel_env_preset() {
  local preset_name="$1"
  local script_dir preset_file

  if [[ "${preset_name}" == "none" ]]; then
    log_info "BSP_PANEL_ENV_PRESET=none, skip merging panel.env preset."
    return
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  preset_file="${PANEL_INSTALL_DIR}/config/panel.env.presets/${preset_name}.env"
  if [[ ! -f "${preset_file}" ]]; then
    preset_file="${script_dir}/../config/panel.env.presets/${preset_name}.env"
  fi
  if [[ ! -f "${preset_file}" ]]; then
    log_warn "Preset file not found: ${preset_name}.env (install dir and repo copy missing)"
    return
  fi

  run_as_root bash -c "printf '\n# --- merged by install.linux.sh (BSP_PANEL_ENV_PRESET=%s) ---\n' \"${preset_name}\" >> \"${PANEL_ENV_FILE}\""
  run_as_root bash -c "cat \"${preset_file}\" >> \"${PANEL_ENV_FILE}\""
  log_info "Merged panel.env preset: ${preset_name} (${preset_file})"
  write_status "deploy" "ok" "Merged panel.env preset ${preset_name}"
}

# 在生成配置与部署前，先校验主机前置条件。
record_preflight_result() {
  PREFLIGHT_FAILURES="$1"
  PREFLIGHT_WARNINGS="$2"
}

# 安装模式的中文说明只在体检报告里用；判定逻辑仍以 RESOLVED_INSTALL_MODE 为准，不要在此处做选择。
install_mode_label() {
  case "${RESOLVED_INSTALL_MODE}" in
    docker)
      printf '%s' 'docker（容器化，面板与游戏都在容器里）'
      ;;
    native)
      printf '%s' 'native（systemd 托管，少一层容器）'
      ;;
    *)
      printf '%s' "${RESOLVED_INSTALL_MODE}"
      ;;
  esac
}

# 面板端口是否已被占用；ss 与 netstat 都没有时按「未占用」放行（后面 check_port_conflict 还会兜底）。
panel_port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${PANEL_PORT}\$" && return 0
    return 1
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${PANEL_PORT}\$" && return 0
    return 1
  fi
  return 1
}

preflight_checks() {
  local arch free_disk_mb host_mem_total_mb
  # 用标量收集「下一步」而不是数组：空数组在 set -u 下的展开会直接中止脚本。
  # 这里不能声明成 local：安装失败时由 handle_install_exit 读出来打印。
  PREFLIGHT_NEXT_STEP=""
  PREFLIGHT_REPORT_LINES=()
  PREFLIGHT_FAILURES=0
  PREFLIGHT_WARNINGS=0

  arch="$(uname -m)"
  free_disk_mb="$(df -Pm / | awk 'NR == 2 { print $4 }')"
  host_mem_total_mb="$(read_host_mem_total_mb)"

  resolve_check_report_path
  write_status "preflight" "start" "Collecting host information"

  append_install_report ""
  append_install_report "前置体检报告"
  append_install_report "  时间：$(date '+%Y-%m-%d %H:%M:%S')    安装器版本：${BSP_RELEASE_TAG}"
  append_install_report "  机器：${DISTRO_ID:-unknown} ${DISTRO_CODENAME:-}（${arch}）"
  append_install_report ""

  # 1) 系统与硬件
  report_item 0 "操作系统" "${DISTRO_ID:-unknown} ${DISTRO_CODENAME:-}（仅支持 apt 系的 Debian 12 与 Ubuntu 22.04 / 24.04）"
  report_item 0 "本机地址" "${HOST_IPV4:-未能解析；用域名访问时请在 panel.env 设置 PANEL_PUBLIC_URL}"

  if [[ "${arch}" == "x86_64" || "${arch}" == "aarch64" ]]; then
    report_item 0 "CPU 架构" "${arch}"
  else
    report_item 2 "CPU 架构" "${arch}（仅支持 x86_64 与 aarch64）"
    report_next_step "换一台 x86_64 或 aarch64 的机器；其他架构没有可用的运行时。"
  fi

  if [[ "${free_disk_mb}" -ge "${MIN_FREE_DISK_MB}" ]]; then
    report_item 0 "根分区余量" "${free_disk_mb} MB（要求不少于 ${MIN_FREE_DISK_MB} MB）"
  else
    report_item 2 "根分区余量" "${free_disk_mb} MB（低于要求的 ${MIN_FREE_DISK_MB} MB）"
    report_next_step "清理根分区或扩容后重跑安装器。"
  fi

  if [[ "${host_mem_total_mb}" -ge "${HOST_MEMORY_WARN_MIN_MB}" ]]; then
    report_item 0 "内存" "${host_mem_total_mb} MB"
  else
    report_item 1 "内存" "${host_mem_total_mb} MB（低于 ${HOST_MEMORY_WARN_MIN_MB} MB）"
  fi

  # 缓存区现状 + 本次安装会不会顺手创建：--check 在这里之后就会退出，所以这一项只是陈述。
  local swap_auto_threshold_mb swap_target_mb
  swap_auto_threshold_mb="${BSP_SWAP_AUTO_THRESHOLD_MB}"
  [[ "${swap_auto_threshold_mb}" =~ ^[0-9]+$ ]] || swap_auto_threshold_mb="${HOST_MEMORY_TIER_SMALL_MAX_MB}"
  if ! command -v swapon >/dev/null 2>&1; then
    report_item 1 "缓存区" "无法检测（缺少 swapon，属于 util-linux 包）"
  elif has_active_swap; then
    report_item 0 "缓存区" "已配置；安装阶段不再改动它（swapon --show 可看详情）"
  elif [[ "${BSP_SWAP_ON_INSTALL}" == "0" || "${BSP_SWAP_ON_INSTALL}" == "off" || "${BSP_SWAP_ON_INSTALL}" == "false" ]]; then
    report_item 1 "缓存区" "未配置；已按 BSP_SWAP_ON_INSTALL=${BSP_SWAP_ON_INSTALL} 关闭自动创建"
    PREFLIGHT_NEXT_STEP="安装完成后执行 sudo bsp setup-swap：分片加载整套 Mod 时会短时冲高内存。"
  elif [[ "${host_mem_total_mb}" -gt 0 && "${host_mem_total_mb}" -lt "${swap_auto_threshold_mb}" ]]; then
    swap_target_mb="$(resolve_auto_swap_size_mb "${host_mem_total_mb}")"
    report_item 1 "缓存区" "未配置；安装阶段会创建 ${swap_target_mb} MiB 缓存区文件（重启后仍生效，--no-swap 可关闭）"
  else
    report_item 1 "缓存区" "未配置；内存档位不需要（低于 ${swap_auto_threshold_mb} MB 的机器会自动创建）"
  fi

  # 2) 平台与运行时
  report_item 0 "部署模式" "$(install_mode_label)"

  if command -v docker >/dev/null 2>&1; then
    local docker_server_version
    docker_server_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)"
    if [[ -n "${docker_server_version}" ]]; then
      report_item 0 "Docker" "已安装且可用（${docker_server_version}）"
    else
      report_item 1 "Docker" "已安装但当前不可用（未启动，或当前账号没有权限）"
    fi
  elif [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    report_item 1 "Docker" "未安装；安装阶段会自动装好（需要能访问软件源）"
  else
    report_item 0 "Docker" "未安装（native 模式不需要）"
  fi

  if [[ "${RESOLVED_INSTALL_MODE}" == "native" ]]; then
    if [[ "${SYSTEMCTL_AVAILABLE}" -eq 1 ]]; then
      report_item 0 "systemd" "systemctl 可用"
    else
      report_item 2 "systemd" "缺少 systemctl"
      report_next_step "换用容器化部署：把 --mode 改成 docker（或直接去掉 --mode）。"
    fi
  fi

  # 3) 网络可达性与镜像路线
  report_item 0 "网络档位" "${RESOLVED_NETWORK_PROFILE}（auto 时按实际连通性判定，可用 --network 覆盖）"

  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    if [[ -n "${PANEL_IMAGE_OVERRIDE}" ]]; then
      report_item 0 "镜像来源" "使用你指定的镜像引用，不做 registry 预检"
    elif [[ "${GHCR_REACHABLE}" -ne 1 ]]; then
      report_item 1 "GHCR" "元数据不可达（https://ghcr.io/v2/ 探不通）"
    elif [[ "${GHCR_LAYER_ACCESSIBLE}" -eq 1 ]]; then
      report_item 0 "GHCR" "元数据可达，层数据实测可用（配置 blob 用时 ${GHCR_LAYER_PROBE_SECONDS}s）"
    else
      # 元数据能通、层数据拉不动是国内最常见的形态：直接拉会挂在 Waiting 上不报错。
      report_item 1 "GHCR" "元数据可达但层数据拉不动，镜像会改走 Release 离线包"
    fi

    case "${IMAGE_ROUTE}" in
      custom)
        report_item 0 "镜像路线" "按你指定的引用拉取"
        ;;
      offline-present)
        report_item 0 "镜像路线" "本地已有 ${PANEL_IMAGE}，跳过下载"
        ;;
      ghcr)
        report_item 0 "镜像路线" "GHCR 直拉（超过 ${DOCKER_PULL_STALL_SECONDS}s 无进度会主动放弃）"
        ;;
      offline)
        report_item 0 "镜像路线" "Release 离线镜像包（走加速代理 + .sha256 校验）"
        ;;
      *)
        ;;
    esac
  fi

  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    if [[ "${DOCKER_REPO_REACHABLE}" -eq 1 ]]; then
      report_item 0 "Docker 官方源" "可达"
    else
      report_item 1 "Docker 官方源" "不可达，安装阶段回退到发行版自带的 docker.io 包"
    fi
  fi

  if [[ "${STEAM_CDN_REACHABLE}" -eq 1 ]]; then
    report_item 0 "Steam CDN" "可达，游戏本体与 Mod 可正常下载"
  else
    report_item 1 "Steam CDN" "不可达"
    report_next_step "装好后到 panel.env 配置 Steam 出站代理与镜像，参数见 docs/reference.md 的「Steam 与 Mod 市场」。"
  fi

  # 4) 端口
  if panel_port_in_use; then
    report_item 2 "面板端口" "TCP ${PANEL_PORT} 已被占用"
    report_next_step "换一个端口重跑：PANEL_PORT=8889，或先停掉占用该端口的服务。"
  else
    report_item 0 "面板端口" "TCP ${PANEL_PORT} 当前未被占用"
  fi

  if [[ "${PREFLIGHT_FAILURES}" -eq 0 && "${PREFLIGHT_WARNINGS}" -eq 0 ]]; then
    append_install_report ""
    append_install_report "体检结论：可以继续安装。"
  elif [[ "${PREFLIGHT_FAILURES}" -eq 0 ]]; then
    append_install_report ""
    append_install_report "体检结论：可以继续安装，但有 ${PREFLIGHT_WARNINGS} 项需要留意。"
    if [[ -n "${PREFLIGHT_NEXT_STEP}" ]]; then
      report_next_step "${PREFLIGHT_NEXT_STEP}"
    fi
  else
    append_install_report ""
    append_install_report "体检结论：有 ${PREFLIGHT_FAILURES} 项不满足安装条件，先按下面的提示处理后重跑。"
  fi
  append_install_report ""

  # 安装模式把同一份报告写进状态文件，便于事后排查；--check 不改动系统，所以不写。
  if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    if try_as_root mkdir -p "${PANEL_LOG_DIR}" \
      && printf '\n----- 前置体检报告（%s）-----' "$(date '+%Y-%m-%d %H:%M:%S')" | try_as_root tee -a "${STATUS_FILE}" >/dev/null \
      && printf '%s\n' "${PREFLIGHT_REPORT_LINES[@]}" | try_as_root tee -a "${STATUS_FILE}" >/dev/null; then
      log_info "Preflight report appended to ${STATUS_FILE}"
    fi
  fi

  write_status "preflight" "ok" "Host checks passed"
}

# 生成运行目录、环境变量文件与 compose 配置。
prepare_panel_files() {
  local script_dir repo_compose compose_source bind_compose steamcmd_attempts existing_port existing_public_url is_upgrade
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_compose="${script_dir}/../docker-compose.yml"
  compose_source="${COMPOSE_SOURCE:-${repo_compose}}"
  steamcmd_attempts=5
  if [[ "${RESOLVED_NETWORK_PROFILE}" == "cn" ]]; then
    steamcmd_attempts=8
  fi

  write_status "deploy" "start" "Preparing runtime files"
  run_as_root mkdir -p "${PANEL_INSTALL_DIR}" "${PANEL_DATA_DIR}" "${PANEL_LOG_DIR}" "${PANEL_INSTANCES_DIR}"
  sync_panel_env_presets
  run_as_root chmod 700 "${PANEL_INSTALL_DIR}"
  run_as_root chmod 750 "${PANEL_DATA_DIR}" "${PANEL_LOG_DIR}" "${PANEL_INSTANCES_DIR}"

  is_upgrade=0
  if try_as_root test -f "${PANEL_ENV_FILE}"; then
    is_upgrade=1
    existing_port="$(read_env_value "${PANEL_ENV_FILE}" "PANEL_PORT")"
    existing_public_url="$(read_env_value "${PANEL_ENV_FILE}" "PANEL_PUBLIC_URL")"
    if [[ "${existing_port}" =~ ^[0-9]+$ ]]; then
      PANEL_PORT="${existing_port}"
    fi
  fi
  detect_host_ip
  resolve_panel_access_urls
  reconcile_existing_public_url "${existing_public_url:-}"

  if [[ -f "${compose_source}" ]]; then
    run_as_root cp "${compose_source}" "${PANEL_COMPOSE_FILE}"
  else
    log_info "Local compose not found, downloading docker-compose.yml from installer mirrors."
    download_installer_asset "docker-compose.yml" "${PANEL_COMPOSE_FILE}" || abort "Failed to download docker-compose.yml from installer mirrors."
  fi
  bind_compose="${script_dir}/../docker-compose.bind.yml"
  if [[ -f "${bind_compose}" ]]; then
    run_as_root cp "${bind_compose}" "${PANEL_BIND_COMPOSE_FILE}"
  else
    download_installer_asset "docker-compose.bind.yml" "${PANEL_BIND_COMPOSE_FILE}" || abort "Failed to download docker-compose.bind.yml from installer mirrors."
  fi

  if [[ "${is_upgrade}" -eq 1 ]]; then
    local old_dst_image old_steamcmd_image
    old_dst_image="$(read_env_value "${PANEL_ENV_FILE}" "BSP_GAME_DST_IMAGE")"
    old_steamcmd_image="$(read_env_value "${PANEL_ENV_FILE}" "BSP_STEAMCMD_IMAGE")"
    if [[ -n "${old_dst_image}" && "${old_dst_image}" != "${PANEL_IMAGE}" ]]; then
      log_info "Detected legacy three-image layout (dst: ${old_dst_image}). Migrating to the v0.2.0 unified image (panel + DST + SteamCMD in one)."
    fi
    if [[ -n "${old_steamcmd_image}" && "${old_steamcmd_image}" != "${PANEL_IMAGE}" ]]; then
      log_info "Legacy SteamCMD image ${old_steamcmd_image} will be replaced by the unified image; old tags can be removed later with docker rmi."
    fi
    run_as_root cp -p "${PANEL_ENV_FILE}" "${PANEL_ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    # 老版本写的 panel.env 可能没有这些键，而 docker-compose.bind.yml 依赖它们：
    # 缺 PANEL_DATA_DIR / PANEL_LOG_DIR 会让 compose 报 "invalid spec: :/app/data: empty section"；
    # 缺 PANEL_PORT 会回退到默认端口，可能撞上宿主机已有服务。仅补缺失项，不覆盖用户设置。
    ensure_env_values "${PANEL_ENV_FILE}" \
      "PANEL_PORT=${PANEL_PORT}" \
      "PANEL_DATA_DIR=${PANEL_DATA_DIR}" \
      "PANEL_LOG_DIR=${PANEL_LOG_DIR}" \
      "PANEL_INSTANCES_DIR=${PANEL_INSTANCES_DIR}" \
      "PANEL_BACKUPS_DIR=${PANEL_BACKUPS_DIR}"
    upsert_env_values "${PANEL_ENV_FILE}" \
      "PANEL_IMAGE=${PANEL_IMAGE}" \
      "BSP_EDITION=community" \
      "BSP_RESOURCE_PREFIX=${BSP_RESOURCE_PREFIX:-bsp}" \
      "BSP_PANEL_DB_FILENAME=${PANEL_DB_FILENAME}" \
      "BSP_PANEL_CONTAINER_NAME=${BSP_PANEL_CONTAINER_NAME:-bubblesharkpanel-panel}" \
      "BSP_NATIVE_SERVICE=${PANEL_NATIVE_SERVICE}" \
      "BSP_RUNTIME_MODE=docker" \
      "BSP_GAME_DST_IMAGE=${BSP_GAME_DST_IMAGE}" \
      "BSP_STEAMCMD_IMAGE=${BSP_STEAMCMD_IMAGE}" \
      "BSP_STACK_DIR=${PANEL_INSTALL_DIR}" \
      "BSP_COMPOSE_FILES=docker-compose.yml:docker-compose.bind.yml" \
      "BSP_GITHUB_REPO=PMAT77/bubble-shark-panel" \
      "BSP_RELEASE_VERSION=${BSP_RELEASE_TAG}"
    log_info "Preserved existing Docker panel.env and updated release/image keys."
  else
    generate_admin_credentials
    # 同 native：printf 逐行写入，凭证值不会被 shell 二次展开。
    local panel_env_tmp
    panel_env_tmp="$(mktemp)"
    {
      printf '%s\n' \
        "PANEL_PORT=${PANEL_PORT}" \
        "PANEL_DATA_DIR=${PANEL_DATA_DIR}" \
        "PANEL_LOG_DIR=${PANEL_LOG_DIR}" \
        "PANEL_INSTANCES_DIR=${PANEL_INSTANCES_DIR}" \
        "PANEL_BACKUPS_DIR=${PANEL_BACKUPS_DIR}" \
        "PANEL_IMAGE=${PANEL_IMAGE}" \
        "# PANEL_PUBLIC_URL：$(panel_public_ip_source_label "${PANEL_PUBLIC_IP_SOURCE}")；换域名/反向代理请直接编辑本行" \
        "PANEL_PUBLIC_URL=${PANEL_ACCESS_URL}" \
        "ADMIN_USERNAME=${ADMIN_USERNAME}" \
        "ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
        "FORCE_PASSWORD_CHANGE=1" \
        "BSP_EDITION=community" \
      "BSP_RESOURCE_PREFIX=${BSP_RESOURCE_PREFIX:-bsp}" \
      "BSP_PANEL_DB_FILENAME=${PANEL_DB_FILENAME}" \
      "BSP_PANEL_CONTAINER_NAME=${BSP_PANEL_CONTAINER_NAME:-bubblesharkpanel-panel}" \
      "BSP_NATIVE_SERVICE=${PANEL_NATIVE_SERVICE}" \
        "BSP_RUNTIME_MODE=docker" \
        "DOCKER_HOST=unix:///var/run/docker.sock" \
        "BSP_GAME_DST_IMAGE=${BSP_GAME_DST_IMAGE}" \
        "BSP_STEAMCMD_IMAGE=${BSP_STEAMCMD_IMAGE}" \
        "BSP_STEAMCMD_INSTALL_MAX_ATTEMPTS=${steamcmd_attempts}" \
        "# BSP_STEAMCMD_INSTALL_RETRY_DELAYS_MS=5000,10000,15000,20000,25000,30000,35000" \
        "# STEAMCMD_USERNAME=" \
        "# STEAMCMD_PASSWORD=" \
        "BSP_STACK_DIR=${PANEL_INSTALL_DIR}" \
        "BSP_COMPOSE_FILES=docker-compose.yml:docker-compose.bind.yml" \
        "BSP_GITHUB_REPO=PMAT77/bubble-shark-panel" \
        "BSP_RELEASE_VERSION=${BSP_RELEASE_TAG}" \
        "TZ=UTC"
    } > "${panel_env_tmp}"
    run_as_root install -m 0600 -o root "${panel_env_tmp}" "${PANEL_ENV_FILE}"
    rm -f "${panel_env_tmp}"
  fi

  if [[ "${is_upgrade}" -eq 0 ]]; then
    local host_mem_total_mb preset_name
    host_mem_total_mb="$(read_host_mem_total_mb)"
    preset_name="$(resolve_panel_env_preset_name "${host_mem_total_mb}")"
    append_panel_env_preset "${preset_name}"
  fi
}

# 仅在部署阶段开始后启用容器栈回滚。
rollback_install() {
  if [[ "${ROLLBACK_ENABLED}" -ne 1 ]]; then
    return
  fi

  write_status "rollback" "start" "Rolling back failed deployment"
  if [[ "${RESOLVED_INSTALL_MODE}" == "native" ]]; then
    log_warn "Native deployment failed, stopping the panel service..."
    run_as_root systemctl stop ${PANEL_NATIVE_SERVICE} >/dev/null 2>&1 || true
    restore_existing_install_state
    if [[ -n "${NATIVE_PREVIOUS_RELEASE}" && -d "${NATIVE_PREVIOUS_RELEASE}" ]]; then
      run_as_root ln -sfn "${NATIVE_PREVIOUS_RELEASE}" "${NATIVE_CURRENT_LINK}.rollback"
      run_as_root mv -Tf "${NATIVE_CURRENT_LINK}.rollback" "${NATIVE_CURRENT_LINK}"
      run_as_root systemctl start ${PANEL_NATIVE_SERVICE} >/dev/null 2>&1 || true
    fi
  else
    log_warn "Deployment failed, rolling back container stack..."
    run_as_root docker compose --env-file "${PANEL_ENV_FILE}" -f "${PANEL_COMPOSE_FILE}" -f "${PANEL_BIND_COMPOSE_FILE}" stop panel >/dev/null 2>&1 || true
    restore_existing_install_state
    if [[ -n "${UPGRADE_STATE_BACKUP_DIR}" ]]; then
      run_as_root docker compose --env-file "${PANEL_ENV_FILE}" -f "${PANEL_COMPOSE_FILE}" -f "${PANEL_BIND_COMPOSE_FILE}" up -d panel >/dev/null 2>&1 || true
    else
      run_as_root docker compose --env-file "${PANEL_ENV_FILE}" -f "${PANEL_COMPOSE_FILE}" -f "${PANEL_BIND_COMPOSE_FILE}" down --remove-orphans >/dev/null 2>&1 || true
    fi
  fi
  write_status "rollback" "ok" "Rollback finished"
}

# 安装阶段可选预拉 SteamCMD（默认不拉，由面板内触发）。
pull_install_steamcmd_image() {
  if [[ "${INSTALL_STEAMCMD_IMAGE}" != "1" ]]; then
    return 0
  fi

  if run_with_retry "docker pull ${INSTALL_STEAMCMD_PULL_IMAGE}" run_as_root docker pull "${INSTALL_STEAMCMD_PULL_IMAGE}"; then
    return 0
  fi

  return 1
}

# 拉取运行时镜像（v0.2.0 起统一镜像：面板/DST/SteamCMD 同一引用，一次拉取全部就绪）。
pull_runtime_images() {
  # 离线镜像包导入后本地已有该 tag；v* tag 不可变，无需重复拉取。
  # 否则弱网环境（GHCR 的镜像层域名常不可达）会在这一步中止整个安装。
  if [[ "${BSP_FORCE_IMAGE_PULL:-0}" != "1" ]] \
    && run_as_root docker image inspect "${PANEL_IMAGE}" >/dev/null 2>&1; then
    log_info "Runtime image already present locally, skipping pull: ${PANEL_IMAGE}"
    return 0
  fi

  # 常见误配：脚本默认 tag 与本地已导入镜像的 tag 不一致（脚本 v0.3.5 + 离线包 v0.3.7）。
  # 安装器只按完整引用判断，对不上就整份重拉；这里先把同仓库的本地 tag 摊开，省去逐条排查。
  local image_repo local_tag_refs tag_ref
  if [[ "${PANEL_IMAGE}" == *"@"* ]]; then
    image_repo="${PANEL_IMAGE%%@*}"
  else
    image_repo="${PANEL_IMAGE%%:*}"
  fi
  local_tag_refs="$(run_as_root docker images --format '{{.Repository}}:{{.Tag}}' "${image_repo}" 2>/dev/null || true)"
  if [[ -n "${local_tag_refs}" ]]; then
    log_warn "Requested runtime image is not present locally: ${PANEL_IMAGE}"
    log_warn "Local images in the same repository:"
    while IFS= read -r tag_ref; do
      if [[ -n "${tag_ref}" ]]; then
        log_warn "  - ${tag_ref}"
      fi
    done <<< "${local_tag_refs}"
    log_warn "若上面就是你要的版本，用 BSP_RELEASE_TAG=<对应的版本 tag> 重跑本安装器即可跳过下载。"
  fi

  if [[ "${IMAGE_ROUTE}" == "ghcr" ]]; then
    log_warn "直拉时若超过 ${DOCKER_PULL_STALL_SECONDS}s 没有进度，安装器会主动放弃，不再无限等下去。"
  fi

  if ! pull_with_stall_detection; then
    log_error "Failed to pull runtime image: ${PANEL_IMAGE}"
    log_error "GHCR 的镜像层域名（pkg-containers.githubusercontent.com）在国内常不可达，表现为 TLS handshake timeout 或长时间 Waiting。"
    log_error "请改用 Release 离线镜像包：下载 $(release_offline_image_filename)（同目录有 .sha256），再用 docker load -i 导入，然后重跑本安装器（镜像已在本地，会自动跳过拉取）。"
    log_error "离线包下载页：https://github.com/PMAT77/bubble-shark-panel/releases/tag/${BSP_RELEASE_TAG}"
    log_error "完整步骤见仓库 docs/install-docker.md 的「安装（国内服务器）」。"
    log_error "如需强制重新拉取，可设置 BSP_FORCE_IMAGE_PULL=1；想固定走直拉可设置 BSP_IMAGE_SOURCE=native。"
    return 1
  fi
}

# 在后台启动 docker pull 并把进度写进日志文件：停滞检测只能靠观察它的输出来判断。
# 重定向的目标是文件而不是管道，进程间管道在受限环境（如 Windows 沙箱）会被拒绝。
start_pull_in_background() {
  local log_path="$1"
  local pid_var="$2"
  run_as_root docker pull "${PANEL_IMAGE}" >"${log_path}" 2>&1 &
  printf -v "${pid_var}" '%s' "$!"
}

# 带停滞检测的直拉：docker pull 卡在传输中不会超时，会把用户挂在 Waiting 上，
# 所以这里盯住进度输出，超过 DOCKER_PULL_STALL_SECONDS 没有新内容就放弃本次尝试。
pull_with_stall_detection() {
  local attempt
  for ((attempt = 1; attempt <= RETRY_MAX; attempt++)); do
    if run_pull_attempt_with_stall_detection; then
      return 0
    fi
    if (( attempt == RETRY_MAX )); then
      log_error "docker pull ${PANEL_IMAGE} failed after ${RETRY_MAX} attempts."
      return 1
    fi
    log_warn "docker pull 第 ${attempt} 次未完成，${RETRY_DELAY_SECONDS}s 后重试（已下载的层会被复用）。"
    sleep "${RETRY_DELAY_SECONDS}"
  done
}

run_pull_attempt_with_stall_detection() {
  local pull_log pull_pid waited last_size current_size stall_seconds
  pull_log="$(run_as_root mktemp /tmp/bsp-pull-XXXXXX)"
  waited=0
  stall_seconds=0

  start_pull_in_background "${pull_log}" pull_pid
  if [[ -z "${pull_pid}" ]]; then
    log_error "无法启动 docker pull（没能取得后台进程号）。"
    return 1
  fi

  last_size=0
  while kill -0 "${pull_pid}" 2>/dev/null; do
    sleep 5
    waited=$((waited + 5))
    current_size="$(run_as_root wc -c < "${pull_log}" 2>/dev/null || printf '0')"
    current_size="${current_size//[^0-9]/}"
    if [[ -z "${current_size}" ]]; then
      current_size=0
    fi
    if [[ "${current_size}" != "${last_size}" ]]; then
      last_size="${current_size}"
      stall_seconds=0
    else
      stall_seconds=$((stall_seconds + 5))
      # 行缓冲模式下进度行会立刻落盘，所以「文件不再增长」等价于「没有新层完成或推进」。
      if (( stall_seconds >= DOCKER_PULL_STALL_SECONDS )); then
        log_warn "docker pull 已连续 ${stall_seconds}s 没有进度，判定停滞并放弃本次尝试。"
        run_as_root kill "${pull_pid}" 2>/dev/null || true
        sleep 2
        run_as_root kill -9 "${pull_pid}" 2>/dev/null || true
        log_warn "已中断停滞的拉取；本地已完成的层会保留，重试或改用离线包都不会从头开始。"
        return 1
      fi
    fi
  done

  if wait "${pull_pid}"; then
    log_info "docker pull completed in ${waited}s: ${PANEL_IMAGE}"
    return 0
  fi
  return 1
}

# Release 离线镜像包名（与 .github/workflows/docker-publish.yml 的资产名保持一致）。
release_offline_image_filename() {
  printf '%s' "bubblesharkpanel-${BSP_RELEASE_TAG}-docker-image.tar.gz"
}

# 下载并校验离线镜像包。
#
# 不走 download_installer_asset：那个函数按仓库相对路径取文件，而镜像包是 Release 资产，
# 路径形状不同；它的校验也依赖脚本内置摘要，而离线包的摘要随构建产生，取不到。
# 所以这里直接拼 Release URL 走加速代理池，并用同目录的 .sha256 对拍（这是发布流程的既定产物）。
download_release_offline_image() {
  local filename asset_url sha_url target_dir target_path proxy source attempt actual expected
  filename="$(release_offline_image_filename)"
  asset_url="https://github.com/PMAT77/bubble-shark-panel/releases/download/${BSP_RELEASE_TAG}/${filename}"
  sha_url="${asset_url}.sha256"
  target_dir="${PANEL_INSTALL_DIR}/offline"
  if ! run_as_root mkdir -p "${target_dir}"; then
    return 1
  fi
  target_path="${target_dir}/${filename}"

  log_info "正在下载离线镜像包 ${filename}（约 227 MB，单次下载上限 ${OFFLINE_IMAGE_MAX_TIME_SECONDS}s）..."
  # build_github_url_variants 返回逗号分隔列表，必须按逗号切分：用默认 IFS 会把整串
  # 当成一个 URL（"a,b,c" 里的逗号不是分隔符），下载必然失败。
  for source in $(build_github_url_variants "${asset_url}" | tr ',' '\n'); do
    for ((attempt = 1; attempt <= REPO_DOWNLOAD_MAX_ATTEMPTS; attempt++)); do
      if run_as_root curl -fL --progress-bar --retry 3 --retry-delay 3 --retry-all-errors \
        --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${OFFLINE_IMAGE_MAX_TIME_SECONDS}" \
        -o "${target_path}" "${source}"; then
        log_info "离线镜像包下载完成：${source}"
        # 摘要必须独立取回并逐个校验：包与校验和来自不同请求，任一被截断都要能拦住。
        if run_as_root curl -fsSL \
          --connect-timeout "${REPO_DOWNLOAD_CONNECT_TIMEOUT_SECONDS}" \
          --max-time "${REPO_DOWNLOAD_TIMEOUT_SECONDS}" \
          -o "${target_path}.sha256" "${source}.sha256"; then
          expected="$(run_as_root awk '{print $1; exit}' "${target_path}.sha256" 2>/dev/null || true)"
          actual="$(run_as_root sha256sum "${target_path}" 2>/dev/null | awk '{print $1}' || true)"
          if [[ -n "${expected}" && "${expected}" == "${actual}" ]]; then
            RELEASE_OFFLINE_IMAGE_PATH="${target_path}"
            return 0
          fi
          log_warn "离线镜像包校验未通过：期望 ${expected:-<空>}，实际 ${actual:-<空>}（重试 ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS}）"
        else
          log_warn "离线镜像包的 .sha256 取不到，按校验失败处理（重试 ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS}）"
        fi
      else
        log_warn "离线镜像包下载失败：${source}（重试 ${attempt}/${REPO_DOWNLOAD_MAX_ATTEMPTS}）"
      fi
      run_as_root rm -f "${target_path}" "${target_path}.sha256" 2>/dev/null || true
      if (( attempt < REPO_DOWNLOAD_MAX_ATTEMPTS )); then
        sleep "${RETRY_DELAY_SECONDS}"
      fi
    done
  done
  return 1
}

# 导入离线镜像包；镜像存在时不再重复导入（BSP_FORCE_IMAGE_PULL=1 时强制重新导入）。
import_release_offline_image() {
  if [[ -z "${RELEASE_OFFLINE_IMAGE_PATH}" ]]; then
    return 1
  fi
  if [[ "${BSP_FORCE_IMAGE_PULL:-0}" != "1" ]] && run_as_root docker image inspect "${PANEL_IMAGE}" >/dev/null 2>&1; then
    log_info "本地已有 ${PANEL_IMAGE}，跳过导入离线镜像包"
    OFFLINE_IMAGE_IMPORTED=1
    return 0
  fi
  log_info "正在导入离线镜像包（约 560 MB）..."
  if ! run_as_root docker load -i "${RELEASE_OFFLINE_IMAGE_PATH}"; then
    log_error "docker load 失败：${RELEASE_OFFLINE_IMAGE_PATH}"
    return 1
  fi
  if ! run_as_root docker image inspect "${PANEL_IMAGE}" >/dev/null 2>&1; then
    log_error "离线镜像包导入后仍找不到 ${PANEL_IMAGE}：包与安装器版本可能不一致（安装器 ${BSP_RELEASE_TAG}）。"
    return 1
  fi
  OFFLINE_IMAGE_IMPORTED=1
  log_info "离线镜像包导入完成：${PANEL_IMAGE}"
  return 0
}

# 镜像准备：按选定路线取镜像，离线包失败时降级到直拉。
#
# 两个方向都留后路：国内默认离线包（代理由加速池跳，比 GHCR 层域名可靠），
# 离线包拿不到时若层数据可达就退回直拉；反过来海外默认直拉，直拉失败由
# pull_runtime_images 负责，它的失败信息会指向离线包。
ensure_panel_image_available() {
  if [[ "${RESOLVED_INSTALL_MODE}" != "docker" ]]; then
    return 0
  fi
  if [[ -n "${PANEL_IMAGE_OVERRIDE}" ]]; then
    return 0
  fi
  # 本地已有目标镜像：pull_runtime_images 本来就会跳过拉取，无需再判断网络。
  if [[ "${BSP_FORCE_IMAGE_PULL:-0}" != "1" ]] && run_as_root docker image inspect "${PANEL_IMAGE}" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${OFFLINE_IMAGE_ROUTE}" -ne 1 ]]; then
    return 0
  fi

  log_info "本次走 Release 离线镜像包（走加速代理，带 .sha256 校验；可用 BSP_IMAGE_SOURCE=native 强制直拉）。"
  if download_release_offline_image && import_release_offline_image; then
    return 0
  fi

  log_warn "离线镜像包不可用。"
  if [[ "${GHCR_LAYER_ACCESSIBLE}" -eq 1 ]]; then
    log_warn "GHCR 层数据实测可达，改为直拉。"
    IMAGE_ROUTE="ghcr"
    return 0
  fi

  log_error "离线镜像包下载或导入失败，且 GHCR 的层数据不可达（预检 ${GHCR_LAYER_PROBE_SECONDS}s/-1 未通过）。"
  log_error "手动下载：https://github.com/PMAT77/bubble-shark-panel/releases/tag/${BSP_RELEASE_TAG}"
  log_error "文件名：$(release_offline_image_filename)（同目录有 .sha256），下载后校验并 docker load -i 导入，再重跑本安装器。"
  return 1
}

wait_for_panel_health() {
  local deadline response
  deadline=$((SECONDS + PANEL_HEALTHCHECK_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if response="$(curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${PANEL_PORT}/health" 2>/dev/null)"; then
      if [[ "${RESOLVED_INSTALL_MODE}" == "native" && "${response}" == *'"mode":"native"'* ]]; then
        # 只看 mode 会把「systemd --user 不可用」也判成安装成功：面板虽然起来了，
        # 却管理不了任何分片，故障要等用户第一次开服才暴露。runtime.status 才代表运行时可用。
        if [[ "${response}" == *'"status":"running"'* ]]; then
          return 0
        fi
      fi
      if [[ "${RESOLVED_INSTALL_MODE}" == "docker" && "${response}" == *'"docker"'* ]]; then
        return 0
      fi
    fi
    sleep "${PANEL_HEALTHCHECK_INTERVAL_SECONDS}"
  done
  LAST_ERROR_MESSAGE="Panel did not become healthy within ${PANEL_HEALTHCHECK_TIMEOUT_SECONDS}s"
  return 1
}

# 拉取镜像并启动服务栈；通过重试应对临时网络抖动。
deploy_panel() {
  begin_stage "images" "Pulling runtime images"
  ROLLBACK_ENABLED=1
  # 先把镜像准备好：GHCR 不可达时这里会自动走 Release 离线包，不必让用户自己下载与导入。
  ensure_panel_image_available || abort "Runtime image is unavailable. See the steps above, or set PANEL_IMAGE to a mirror you control."
  pull_runtime_images || abort "Image pull failed. Check outbound network or configure explicit image references. Native fallback: rerun with --mode native."
  write_status "images" "ok" "Runtime image pull completed"

  begin_stage "startup" "Starting panel stack"
  run_with_retry "docker compose up" run_as_root docker compose --env-file "${PANEL_ENV_FILE}" -f "${PANEL_COMPOSE_FILE}" -f "${PANEL_BIND_COMPOSE_FILE}" up -d
  write_status "startup" "ok" "Panel stack started"

  begin_stage "health" "Waiting for panel health endpoint"
  wait_for_panel_health
  write_status "health" "ok" "Panel health endpoint is ready"
}

deploy_native_panel() {
  begin_stage "native-release" "Installing Native Release"
  if run_as_root test -L "${NATIVE_CURRENT_LINK}"; then
    NATIVE_PREVIOUS_RELEASE="$(readlink -f "${NATIVE_CURRENT_LINK}" || true)"
  fi
  ROLLBACK_ENABLED=1
  install_native_release
  install_native_steamcmd
  install_native_update_helper
  write_status "native-release" "ok" "Native Release and SteamCMD installed"

  begin_stage "configuration" "Preparing Native systemd service"
  prepare_native_panel_env
  write_status "configuration" "ok" "Native configuration prepared"

  begin_stage "startup" "Starting Native panel service"
  run_as_root systemctl enable --now ${PANEL_NATIVE_SERVICE}
  if [[ "${NATIVE_RELEASE_REPLACED}" -eq 1 ]]; then
    # enable --now 对已在运行的服务是空操作，而升级换的是 current 符号链接：
    # 不重启的话面板进程仍跑旧版本，升级看似成功但界面还是旧版。
    run_as_root systemctl try-restart ${PANEL_NATIVE_SERVICE}
    log_info "Restarted the panel service to load ${BSP_RELEASE_TAG}."
  fi
  write_status "startup" "ok" "Native panel service started"

  begin_stage "health" "Waiting for Native panel health endpoint"
  wait_for_panel_health
  write_status "health" "ok" "Native panel health endpoint is ready"
}

# 部署 bsp CLI 到 /usr/local/bin（优先本地仓库，其次镜像池下载）。
install_gsh_cli() {
  local script_dir src tmp
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  src="${script_dir}/../scripts/bsp.sh"
  if [[ ! -f "${src}" ]]; then
    tmp="$(mktemp)"
    if download_installer_asset "scripts/bsp.sh" "${tmp}"; then
      src="${tmp}"
    else
      log_warn "bsp.sh not available locally or from mirrors; skip CLI install."
      return 0
    fi
  fi
  run_as_root install -m 0755 "${src}" /usr/local/bin/bsp
  run_as_root ln -sfn bsp /usr/local/bin/gsh
  log_info "Installed panel CLI: /usr/local/bin/bsp (try: bsp doctor)"
}

# 面板内更新（Native）的触发单元：面板只写请求文件，真正的安装动作由 root 的 oneshot 服务执行。
native_update_service_unit() {
  cat <<EOF
[Unit]
Description=BubbleSharkPanel panel update (Native release install)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
# 把安装期确定下来的真实路径注入执行器：panel.env 里没有这些键（BSP_STACK_DIR 是 Docker 分支的键），
# 自定义 PANEL_INSTALL_DIR / PANEL_DATA_DIR 的机器就靠它找到安装目录与交换目录。
Environment="BSP_PANEL_ENV_FILE=${PANEL_ENV_FILE}"
Environment="BSP_NATIVE_SERVICE=${PANEL_NATIVE_SERVICE}"
Environment="BSP_INSTALL_DIR=${PANEL_INSTALL_DIR}"
Environment="BSP_NATIVE_UPDATE_DIR=${NATIVE_UPDATE_DIR}"
Environment="BSP_NATIVE_USER=${NATIVE_SERVICE_USER}"
ExecStart=${NATIVE_UPDATE_HELPER_PATH}
TimeoutStartSec=2700
EOF
}

native_update_path_unit() {
  cat <<EOF
[Unit]
Description=Watch the panel update request for BubbleSharkPanel (Native)

[Path]
PathExists=${NATIVE_UPDATE_DIR}/request
Unit=${NATIVE_UPDATE_SERVICE}

[Install]
WantedBy=multi-user.target
EOF
}

# 部署特权更新执行器（优先本地仓库，其次镜像池下载）；幂等，升级重跑时覆盖旧单元。
install_native_update_helper() {
  local script_dir src tmp service_tmp path_tmp
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
  src=""
  if [[ -n "${script_dir}" && -f "${script_dir}/bsp-native-update.sh" ]]; then
    src="${script_dir}/bsp-native-update.sh"
  elif [[ -n "${script_dir}" && -f "${script_dir}/../scripts/bsp-native-update.sh" ]]; then
    src="${script_dir}/../scripts/bsp-native-update.sh"
  fi
  if [[ -z "${src}" ]]; then
    tmp="$(mktemp)"
    if download_installer_asset "scripts/bsp-native-update.sh" "${tmp}"; then
      src="${tmp}"
    else
      log_warn "bsp-native-update.sh not available locally or from mirrors; panel updates will keep asking for a manual command."
      return 0
    fi
  fi

  # 先落到 .new 再原子改名：升级时这个脚本很可能正在被自己触发的那次更新执行（本脚本
  # 在后台跑安装器），直接覆盖正在运行的文件会撞上 "Text file busy" 让整次升级失败。
  run_as_root install -D -m 0755 "${src}" "${NATIVE_UPDATE_HELPER_PATH}.new"
  run_as_root mv -f "${NATIVE_UPDATE_HELPER_PATH}.new" "${NATIVE_UPDATE_HELPER_PATH}"
  # 请求文件目录归面板服务用户所有：它需要写请求，但拿不到 root。
  run_as_root mkdir -p "${NATIVE_UPDATE_DIR}"
  run_as_root chown "${NATIVE_SERVICE_USER}:${NATIVE_SERVICE_GROUP}" "${NATIVE_UPDATE_DIR}"
  run_as_root chmod 0750 "${NATIVE_UPDATE_DIR}"

  service_tmp="$(mktemp)"
  path_tmp="$(mktemp)"
  native_update_service_unit > "${service_tmp}"
  native_update_path_unit > "${path_tmp}"
  run_as_root install -m 0644 "${service_tmp}" "${NATIVE_UPDATE_SERVICE_UNIT}"
  run_as_root install -m 0644 "${path_tmp}" "${NATIVE_UPDATE_PATH_UNIT_FILE}"
  rm -f "${service_tmp}" "${path_tmp}"

  run_as_root systemctl daemon-reload
  run_as_root systemctl enable --now "${NATIVE_UPDATE_PATH_UNIT}"
  log_info "Installed panel update helper: ${NATIVE_UPDATE_HELPER_PATH} (trigger: ${NATIVE_UPDATE_PATH_UNIT})"
}

# 输出最终访问信息与安全提醒。
# 关键信息用不带日志前缀的边框区块呈现：安装日志很长，带 [INFO] 前缀的收尾行很容易被忽略。
print_summary() {
  write_status "install" "ok" "Installation completed"
  INSTALL_COMPLETED=1
  CURRENT_STAGE="complete"

  local rule sub_rule
  rule="======================================================================"
  sub_rule="----------------------------------------------------------------------"

  printf '\n%s\n' "${rule}"
  printf ' 安装完成：bubblesharkpanel %s\n' "${BSP_RELEASE_TAG}"
  printf ' 部署模式：%s    网络档：%s\n' "${RESOLVED_INSTALL_MODE}" "${RESOLVED_NETWORK_PROFILE}"
  printf '%s\n' "${rule}"
  printf ' 面板地址   %s（%s）\n' "${PANEL_ACCESS_URL}" "$(panel_public_ip_source_label "${PANEL_PUBLIC_IP_SOURCE}")"
  if [[ "${PANEL_LAN_URL}" != "${PANEL_ACCESS_URL}" ]]; then
    printf ' 内网地址   %s（仅同一局域网可访问）\n' "${PANEL_LAN_URL}"
  fi
  printf ' 管理员     %s\n' "${ADMIN_USERNAME}"
  if [[ "${HIDE_ADMIN_PASSWORD}" == "1" ]]; then
    printf ' 初始密码   已按要求隐藏，用下面这条命令读取：\n'
    printf "sudo sed -n 's/^ADMIN_PASSWORD=//p' %s\n" "${PANEL_ENV_FILE}"
  else
    printf ' 初始密码   %s\n' "${ADMIN_PASSWORD}"
    printf '            （首次登录会强制改密；该密码也写在 %s）\n' "${PANEL_ENV_FILE}"
  fi
  printf '%s\n' "${sub_rule}"
  if [[ "${RESOLVED_INSTALL_MODE}" == "native" ]]; then
    printf ' 面板服务   %s（sudo systemctl status 查看）\n' "${PANEL_NATIVE_SERVICE}"
    printf ' 程序目录   %s\n' "${NATIVE_CURRENT_LINK}"
  else
    printf ' 运行镜像   %s\n' "${PANEL_IMAGE}"
    printf ' 安装目录   %s\n' "${PANEL_INSTALL_DIR}"
  fi
  printf ' 常用命令   bsp doctor（体检）· bsp status（状态）· bsp setup-swap（缓存区）\n'
  # 用 date 而不是 SECONDS：冒烟测试里 source 过来的 SECONDS 受到其它脚本影响，读数不可靠。
  local elapsed_seconds=$(( $(date +%s) - INSTALL_STARTED_AT ))
  if (( elapsed_seconds < 0 )); then
    elapsed_seconds=0
  fi
  printf ' 安装耗时   %d 分 %d 秒（含依赖与镜像下载）\n' "$((elapsed_seconds / 60))" "$((elapsed_seconds % 60))"
  printf ' 安装状态   %s\n' "${STATUS_FILE}"
  printf '%s\n' "${rule}"
  printf ' 接下来\n'
  printf ' 1. 浏览器打开上面的面板地址登录；首次登录会强制修改初始密码\n'
  case "${PANEL_PUBLIC_IP_SOURCE}" in
    lan)
      printf ' 2. 没能自动探测到公网地址：上面是本机内网地址，只有同一内网可访问；\n'
      printf '    公网访问请把主机名换成本机公网 IP 或域名，并在云安全组放行 TCP %s\n' "${PANEL_PORT}"
      printf '    也可以指定地址后重跑安装：PANEL_PUBLIC_URL=http://<公网IP>:%s\n' "${PANEL_PORT}"
      ;;
    ip_echo)
      printf ' 2. 上面的公网地址来自出站 IP 探测：仅当该公网 IP 已映射到本机端口时可用；\n'
      printf '    服务器若在运营商 NAT（CGNAT）后面，请换成实际映射的地址，并放行 TCP %s\n' "${PANEL_PORT}"
      ;;
    *)
      printf ' 2. 公网访问直接用上面的地址；用域名或反向代理时请在 panel.env 改 PANEL_PUBLIC_URL，\n'
      printf '    并在云安全组放行 TCP %s\n' "${PANEL_PORT}"
      ;;
  esac
  printf ' 3. 到「实例管理」创建第一个实例：填房间名与端口后启动，面板会拉取游戏本体并生成世界\n'
  printf ' 4. 开服前放行 6 个 UDP 端口（主世界与洞穴各 3 个），否则玩家搜不到房间\n'
  # 注意：这里不能用 `[[ ... ]] && printf`——条件不成立时整个语句返回非零码，
  # 在 set -e 下会触发 ERR trap，把一次正常安装判成失败。
  case "${AUTO_SWAP_STATE}" in
    created)
      printf ' 5. 已自动创建 %s MiB 缓存区（/etc/fstab 已写入，重启后仍生效）；\n' "${AUTO_SWAP_TARGET_MB}"
      printf '    查看：swapon --show；调整大小见 docs/MEMORY.md\n'
      ;;
    active)
      printf ' 5. 检测到已有缓存区，安装器未做改动；内存偏小时见 docs/MEMORY.md\n'
      ;;
    skipped)
      case "${AUTO_SWAP_SKIPPED_REASON}" in
        disk)
          printf ' 5. 根分区余量不足，未创建缓存区；腾出空间后执行 sudo bsp setup-swap\n'
          ;;
        disabled)
          printf ' 5. 已按要求跳过自动缓存区；需要时执行 sudo bsp setup-swap（docs/MEMORY.md）\n'
          ;;
        memory-ok)
          printf ' 5. 内存充足，未创建缓存区\n'
          ;;
        *)
          printf ' 5. 未能自动配置缓存区；内存偏小时执行 sudo bsp setup-swap（docs/MEMORY.md）\n'
          ;;
      esac
      ;;
    failed)
      printf ' 5. 自动创建缓存区失败（不阻断安装）；请手动执行 sudo bsp setup-swap，详见 docs/MEMORY.md\n'
      ;;
    *)
      printf ' 5. 内存偏小（≤ 6 GiB）建议执行 sudo bsp setup-swap，详见 docs/MEMORY.md\n'
      ;;
  esac
  printf '%s\n\n' "${rule}"

  # 排障用的长命令留在带前缀的日志里，方便复制粘贴。
  if [[ "${RESOLVED_INSTALL_MODE}" == "native" ]]; then
    log_info "Native release: ${NATIVE_CURRENT_LINK}; SteamCMD: ${NATIVE_STEAMCMD_PATH}"
  else
    log_info "Compose: cd ${PANEL_INSTALL_DIR} && docker compose --env-file panel.env -f docker-compose.yml -f docker-compose.bind.yml ps"
    log_info "Panel logs: cd ${PANEL_INSTALL_DIR} && docker compose logs -f panel"
    if [[ -n "${RELEASE_OFFLINE_IMAGE_PATH}" ]]; then
      log_info "离线镜像包已导入；安装目录的 offline/ 下保留了安装包，确认面板正常后可自行删除。"
    fi
  fi
}

# 主流程：安装依赖 -> 预检 -> 网络处理 -> 生成配置 -> 部署。
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ $# -ge 2 ]] || abort "--mode requires auto, docker or native."
        INSTALL_MODE="$2"
        shift 2
        ;;
      --mode=*)
        INSTALL_MODE="${1#*=}"
        shift
        ;;
      --network)
        [[ $# -ge 2 ]] || abort "--network requires auto, cn or global."
        NETWORK_PROFILE="$2"
        shift 2
        ;;
      --network=*)
        NETWORK_PROFILE="${1#*=}"
        shift
        ;;
      --open-panel-port)
        OPEN_PANEL_PORT=1
        shift
        ;;
      --open-dst-ports)
        OPEN_DST_PORTS=1
        shift
        ;;
      --no-swap)
        BSP_SWAP_ON_INSTALL=0
        shift
        ;;
      --check)
        CHECK_ONLY=1
        shift
        ;;

      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        abort "Unknown option: $1 (use --help)"
        ;;
    esac
  done

  # ERR 记录失败位置；EXIT 统一写状态、生成脱敏诊断并执行部署回滚。
  trap 'record_install_error "$?" "$LINENO"' ERR
  trap 'handle_install_exit "$?"' EXIT

  log_info "Running ${SCRIPT_NAME}..."
  begin_stage "install" "Installer started"

  CURRENT_STAGE="platform"
  detect_distro
  ensure_apt
  resolve_network_profile
  resolve_install_mode
  validate_install_mode_transition
  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    finalize_image_refs
    # 自证身份：脚本默认 tag 与本地镜像 tag 不一致时，这一行最先暴露问题（含实际执行的文件名）。
    log_info "Installer: ${SCRIPT_NAME} release=${BSP_RELEASE_TAG} image=${PANEL_IMAGE}"
  fi

  INSTALL_STARTED_AT="$(date +%s)"

  # 体检必须在装依赖之前：缺 Docker 的机器从前要先花几分钟装依赖，再在预检里失败。
  CURRENT_STAGE="preflight"
  resolve_check_report_path
  probe_reachability
  # 路线要在体检之前定下来：报告里会说明这次走 GHCR 直拉还是离线镜像包。
  resolve_image_route
  preflight_checks

  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    # 只体检：不改动系统，所以到此为止（上面除 detect_distro/ensure_apt 的只读探测外没有任何写操作）。
    INSTALL_COMPLETED=1
    if [[ "${PREFLIGHT_FAILURES}" -gt 0 ]]; then
      exit 1
    fi
    exit 0
  fi

  if [[ "${PREFLIGHT_FAILURES}" -gt 0 ]]; then
    abort "Preflight checks failed: ${PREFLIGHT_FAILURES} item(s) must be fixed before installing. See the report above."
  fi

  begin_stage "dependencies" "Installing base dependencies"
  install_base_packages
  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    if ! install_docker; then
      abort "Docker installation failed. See /var/log/bubblesharkpanel/install.status and the troubleshooting section in docs/install-docker.md; if the error above contains manual commands, run them and rerun this installer."
    fi
    add_user_to_docker_group
    write_status "dependencies" "ok" "Docker dependencies installed"
  else
    install_native_dependencies
    ensure_native_service_user
    write_status "dependencies" "ok" "Native systemd dependencies installed"
  fi
  # bsp CLI 必须在自动 swap 之前就位：面板容器不以 root 运行，创建缓存区需要 root，
  # 所以安装器是唯一能一次性把这件事做掉的环节（也是 bsp setup-swap 的兜底）。
  install_gsh_cli
  backup_existing_install_state

  begin_stage "swap" "Preparing the swapfile for small-RAM hosts"
  ensure_small_host_swap
  write_status "swap" "ok" "Swap check finished (${AUTO_SWAP_STATE})"

  begin_stage "network" "Checking panel port and firewall"
  check_port_conflict
  if [[ "${OPEN_PANEL_PORT}" -eq 1 ]]; then
    open_firewall_port
  else
    log_info "Panel TCP port not opened automatically. Use --open-panel-port or configure firewall/security-group manually."
  fi
  if [[ "${OPEN_DST_PORTS}" -eq 1 ]]; then
    open_firewall_dst_ports
  else
    log_info "DST UDP ports not opened automatically. Use --open-dst-ports or configure firewall manually (see docs/install-docker.md)."
  fi
  write_status "network" "ok" "Port and firewall processed"

  if [[ "${RESOLVED_INSTALL_MODE}" == "docker" ]]; then
    begin_stage "configuration" "Preparing Docker panel configuration"
    prepare_panel_files
    write_status "configuration" "ok" "Docker panel configuration prepared"
    deploy_panel
  else
    deploy_native_panel
  fi

  print_summary
}

if [[ "${BSP_INSTALLER_LIB_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
