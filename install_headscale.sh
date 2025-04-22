#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="headscale-offline-package.tar.gz"

# 1. 解压离线包
echo ">> 解压离线包：${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C /

# 2. 创建 headscale 用户和目录
echo ">> 创建 headscale 系统用户"
id -u headscale &>/dev/null || \
  useradd --system --create-home --home-dir /var/lib/headscale --shell /usr/sbin/nologin headscale

# 3. 设置权限
echo ">> 设置目录权限"
mkdir -p /var/lib/headscale
chown -R headscale:headscale /var/lib/headscale

# 4. 安装 systemd 服务
echo ">> 安装并启动 systemd 服务"
systemctl daemon-reload
systemctl enable --now headscale

echo "Headscale 安装并启动完成 🎉"
