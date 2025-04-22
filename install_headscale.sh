#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
USER="headscale"
HOME_DIR="/var/lib/${USER}"
SHELL="/usr/sbin/nologin"

# 检查以 root 身份运行
if [[ $EUID -ne 0 ]]; then
  echo "请使用 root 用户运行此脚本"
  exit 1
fi

# 检查离线包是否存在
if [[ ! -f "${ARCHIVE}" ]]; then
  echo "未找到离线包 ${ARCHIVE}，请将其放在当前目录后重试"
  exit 1
fi

# 1. 解压离线包
echo ">> 解压离线包：${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C /

# 2. 创建系统用户（useradd/adduser 二选一，必要时自动安装）
create_system_user() {
  echo ">> 创建或检查系统用户：${USER}"

  # 如果用户已存在，直接返回
  if id "${USER}" &>/dev/null; then
    echo "用户 ${USER} 已存在，跳过创建"
    return
  fi

  # 定义创建函数
  _do_useradd() {
    useradd --system \
            --create-home \
            --home-dir "${HOME_DIR}" \
            --shell "${SHELL}" \
            "${USER}"
  }
  _do_adduser() {
    adduser --system \
            --home "${HOME_DIR}" \
            --no-create-home \
            --shell "${SHELL}" \
            "${USER}"
  }

  # 优先使用 useradd
  if command -v useradd &>/dev/null; then
    _do_useradd && return
  fi

  # 其次尝试 adduser
  if command -v adduser &>/dev/null; then
    _do_adduser && return
  fi

  # 如果两者都不存在，尝试安装所需包
  echo "检测到无 useradd/adduser，尝试安装 shadow-utils 或 passwd 包…"
  if command -v apt-get &>/dev/null; then
    apt-get update
    apt-get install -y passwd
  elif command -v yum &>/dev/null; then
    yum install -y shadow-utils
  elif command -v zypper &>/dev/null; then
    zypper install -y shadow
  elif command -v apk &>/dev/null; then
    apk add shadow
  elif command -v pacman &>/dev/null; then
    pacman -Sy --noconfirm shadow
  else
    echo "无法识别的发行版，无法自动安装用户管理工具，请手动安装 useradd/adduser" >&2
    exit 1
  fi

  # 安装完成后重试创建
  if command -v useradd &>/dev/null; then
    _do_useradd
  elif command -v adduser &>/dev/null; then
    _do_adduser
  else
    echo "安装后依然无法找到 useradd/adduser，请手动创建用户 ${USER}" >&2
    exit 1
  fi
}

create_system_user

# 3. 设置数据目录权限
echo ">> 设置目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R "${USER}:${USER}" "${HOME_DIR}"

# 4. 安装并启动 systemd 服务
echo ">> 安装并启动 systemd 服务：${SERVICE}.service"
if ! command -v systemctl &>/dev/null; then
  echo "警告：未检测到 systemctl，请确保后续手动加载并启动 ${SERVICE}.service"
else
  systemctl daemon-reload
  systemctl enable --now "${SERVICE}"
fi

echo "✅ Headscale 安装并启动完成！"
