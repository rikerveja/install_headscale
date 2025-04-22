#!/usr/bin/env bash
set -euo pipefail

# 设置 PATH 环境变量，确保能够找到必要的系统命令
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
INSTALL_DIR="/opt/headscale"
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

# 解压离线包到指定目录，避免覆盖系统目录
echo ">> 解压离线包：${ARCHIVE}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"

# 设置数据目录权限
echo ">> 设置目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R root:root "${HOME_DIR}"

# 启动 systemd 服务
echo ">> 启动 systemd 服务：${SERVICE}.service"
if command -v systemctl &>/dev/null; then
  systemctl daemon-reload
  systemctl enable --now "${SERVICE}"
  echo "✅ Headscale 服务已启动（以 root 用户运行）"
else
  echo "警告：未检测到 systemctl，请手动加载并启动 ${SERVICE}.service"
fi
