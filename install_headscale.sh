#!/usr/bin/env bash
set -euo pipefail

# 设置 PATH 环境变量，确保能够找到必要的系统命令
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ARCHIVE="headscale-offline-package.tar.gz"
SERVICE="headscale"
INSTALL_DIR="/opt/headscale"
HOME_DIR="/var/lib/headscale"
EXECUTABLE="/usr/local/bin/headscale"

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

# 将可执行文件移动到 /usr/local/bin 并赋予执行权限
echo ">> 安装 Headscale 可执行文件"
cp "${INSTALL_DIR}/headscale" "${EXECUTABLE}"
chmod +x "${EXECUTABLE}"

# 设置数据目录权限
echo ">> 设置目录权限：${HOME_DIR}"
mkdir -p "${HOME_DIR}"
chown -R root:root "${HOME_DIR}"

# 创建 systemd 服务文件
echo ">> 创建 systemd 服务文件：/etc/systemd/system/${SERVICE}.service"
cat <<EOF > /etc/systemd/system/${SERVICE}.service
[Unit]
Description=Headscale Controller
After=network.target

[Service]
Type=simple
ExecStart=${EXECUTABLE} serve
WorkingDirectory=${HOME_DIR}
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
echo ">> 启动 systemd 服务：${SERVICE}.service"
systemctl daemon-reload
systemctl enable --now "${SERVICE}"
echo "✅ Headscale 服务已启动（以 root 用户运行）"
