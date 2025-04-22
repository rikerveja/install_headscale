#!/usr/bin/env bash
set -euo pipefail

# 设置 PATH 环境变量，确保能够找到必要的系统命令
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
INSTALL_DIR="/opt/headscale"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"
CONFIG_DIR="/etc/headscale"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
HOME_DIR="/var/lib/headscale"

# 仅允许 root 用户运行
if [[ $EUID -ne 0 ]]; then
  echo "请使用 root 用户运行此脚本"
  exit 1
fi

# 检查离线包是否存在
if [[ ! -f "${ARCHIVE}" ]]; then
  echo "未找到离线包 ${ARCHIVE}，请将其放在当前目录后重试"
  exit 1
fi

# 解压离线包到指定目录
echo ">> 解压离线包：${ARCHIVE}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"

# 安装 Headscale 可执行文件
echo ">> 安装 Headscale 可执行文件"
EXECUTABLE_PATH="${INSTALL_DIR}/usr/local/bin/headscale"
if [[ -f "${EXECUTABLE_PATH}" ]]; then
  cp "${EXECUTABLE_PATH}" "${BIN_DIR}/headscale"
  chmod +x "${BIN_DIR}/headscale"
else
  echo "❌ 未找到可执行文件：${EXECUTABLE_PATH}"
  exit 1
fi

# 安装 systemd 服务文件
echo ">> 安装 systemd 服务文件"
SERVICE_SRC="${INSTALL_DIR}/lib/systemd/system/${SERVICE}.service"
if [[ -f "${SERVICE_SRC}" ]]; then
  cp "${SERVICE_SRC}" "${SERVICE_FILE}"
else
  echo "❌ 未找到 systemd 服务文件：${SERVICE_SRC}"
  exit 1
fi

# 创建配置目录和文件
echo ">> 创建配置目录和文件"
mkdir -p "${CONFIG_DIR}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  cat <<EOF > "${CONFIG_FILE}"
server_url: http://127.0.0.1:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
private_key_path: ${HOME_DIR}/private.key
noise:
  private_key_path: ${HOME_DIR}/noise_private.key
db_type: sqlite3
db_path: ${HOME_DIR}/db.sqlite
EOF
fi

# 设置数据目录权限
echo ">> 设置数据目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R root:root "${HOME_DIR}"

# 启动 systemd 服务
echo ">> 启动 systemd 服务：${SERVICE}.service"
if command -v systemctl &>/dev/null; then
  systemctl daemon-reload
  systemctl enable --now "${SERVICE}"
  echo "✅ Headscale 服务已启动（以 root 用户运行）"
else
  echo "⚠️ 警告：未检测到 systemctl，请手动加载并启动 ${SERVICE}.service"
fi
