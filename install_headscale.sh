#!/usr/bin/env bash
set -euo pipefail

# 设置 PATH 环境变量，确保能够找到必要的系统命令
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
USER="headscale"
HOME_DIR="/var/lib/${USER}"
SHELL="/usr/sbin/nologin"
INSTALL_DIR="/opt/headscale"

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

# 创建或检查系统用户
echo ">> 创建或检查系统用户：${USER}"
if id "${USER}" &>/dev/null; then
  echo "用户 ${USER} 已存在，跳过创建"
else
  if command -v useradd &>/dev/null; then
    useradd --system --create-home --home-dir "${HOME_DIR}" \
            --shell "${SHELL}" "${USER}" && echo "使用 useradd 创建用户"
  elif command -v adduser &>/dev/null; then
    if command -v apk &>/dev/null; then
      addgroup -S "${USER}"
      adduser -S -G "${USER}" -h "${HOME_DIR}" -s "${SHELL}" "${USER}" \
        && echo "使用 BusyBox adduser 创建用户"
    else
      adduser --system --home "${HOME_DIR}" --shell "${SHELL}" "${USER}" \
        && echo "使用 Debian adduser 创建用户"
    fi
  else
    echo "无法识别的发行版或包管理器，跳过用户创建，服务将以 root 身份运行" >&2
    USER="root"
    HOME_DIR="/root"
  fi
fi

# 设置数据目录权限
echo ">> 设置目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R "${USER}:${USER}" "${HOME_DIR}"

# 启动 systemd 服务
echo ">> 启动 systemd 服务：${SERVICE}.service"
if command -v systemctl &>/dev/null; then
  systemctl daemon-reload
  systemctl enable --now "${SERVICE}"
  echo "✅ Headscale 服务已启动（用户：${USER}）"
else
  echo "警告：未检测到 systemctl，请手动加载并启动 ${SERVICE}.service"
fi
