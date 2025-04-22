#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
USER="headscale"
HOME_DIR="/var/lib/${USER}"
SHELL="/usr/sbin/nologin"

# 仅允许 root 运行
if [[ $EUID -ne 0 ]]; then
  echo "请使用 root 用户运行此脚本"
  exit 1
fi

# 检查离线包
if [[ ! -f "${ARCHIVE}" ]]; then
  echo "未找到离线包 ${ARCHIVE}，请将其放在当前目录后重试"
  exit 1
fi

# 1. 解压离线包
echo ">> 解压离线包：${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C /

# 2. 创建或检查系统用户
echo ">> 创建或检查系统用户：${USER}"
if id "${USER}" &>/dev/null; then
  echo "用户 ${USER} 已存在，跳过创建"
else
  # 2.1 优先使用 useradd（来自 shadow-utils 包）&#8203;:contentReference[oaicite:2]{index=2}
  if command -v useradd &>/dev/null; then
    useradd --system --create-home --home-dir "${HOME_DIR}" \
            --shell "${SHELL}" "${USER}" && echo "使用 useradd 创建用户"
  # 2.2 尝试 adduser（Debian 或 BusyBox）&#8203;:contentReference[oaicite:3]{index=3}
  elif command -v adduser &>/dev/null; then
    # 如果在 Alpine/BusyBox 中，使用 BusyBox 风格参数
    if command -v apk &>/dev/null; then
      addgroup -S "${USER}"
      adduser -S -G "${USER}" -h "${HOME_DIR}" -s "${SHELL}" "${USER}" \
        && echo "使用 BusyBox adduser 创建用户"
    else
      adduser --system --home "${HOME_DIR}" --shell "${SHELL}" "${USER}" \
        && echo "使用 Debian adduser 创建用户"
    fi
  # 2.3 尝试自动安装 shadow-utils 或 busybox
  else
    echo "检测到无 useradd/adduser，可尝试安装必要工具…"
    if command -v apt-get &>/dev/null; then
      apt-get update && apt-get install -y passwd
    elif command -v yum &>/dev/null; then
      yum install -y shadow-utils
    elif command -v microdnf &>/dev/null; then
      microdnf install -y shadow-utils
    elif command -v zypper &>/dev/null; then
      zypper install -y shadow
    elif command -v apk &>/dev/null; then
      apk update && apk add shadow
    elif command -v pacman &>/dev/null; then
      pacman -Sy --noconfirm shadow
    else
      echo "无法识别的发行版或包管理器，跳过用户创建，服务将以 root 身份运行" >&2
      USER="root"
      HOME_DIR="/root"
    fi

    # 安装完成后再次尝试创建
    if [[ "${USER}" != "root" ]]; then
      if command -v useradd &>/dev/null; then
        useradd --system --create-home --home-dir "${HOME_DIR}" \
                --shell "${SHELL}" "${USER}" && echo "安装工具后使用 useradd 创建用户"
      elif command -v adduser &>/dev/null; then
        adduser --system --home "${HOME_DIR}" --shell "${SHELL}" "${USER}" \
          && echo "安装工具后使用 adduser 创建用户"
      else
        echo "依旧无法创建用户，服务将以 root 身份运行" >&2
        USER="root"
        HOME_DIR="/root"
      fi
    fi
  fi
fi

# 3. 设置数据目录权限
echo ">> 设置目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R "${USER}:${USER}" "${HOME_DIR}"

# 4. 启动 systemd 服务
echo ">> 启动 systemd 服务：${SERVICE}.service"
if command -v systemctl &>/dev/null; then
  systemctl daemon-reload
  systemctl enable --now "${SERVICE}"
  echo "✅ Headscale 服务已启动（用户：${USER}）"
else
  echo "警告：未检测到 systemctl，请手动加载并启动 ${SERVICE}.service"
fi
