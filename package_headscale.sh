#!/usr/bin/env bash
set -euo pipefail

# —— 动态获取最新 HEADSCALE_VERSION ——  
# 从 GitHub 官方仓库列出所有 tags，提取标签名(vX.Y.Z)，按版本排序，取最新一个  
GIT_SOURCE="https://github.com/juanfont/headscale.git"
LATEST_TAG=$(git ls-remote --tags "${GIT_SOURCE}" \
  | awk -F/ '{print $NF}' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n1)                                   # 按语义化版本排序并取最后一项 :contentReference[oaicite:1]{index=1}
HEADSCALE_VERSION="${LATEST_TAG#v}"
GIT_REPO="${GIT_SOURCE}"
GO_VERSION="1.24.0"                # 与 go.mod 中版本保持一致  
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
OFFLINE_DIR="headscale-offline"
ARCHIVE="headscale-offline-package.tar.gz"

echo ">> 使用 Headscale 版本：${HEADSCALE_VERSION}"

# 1. 准备 Go 工具链  
echo ">> 准备 Go 工具链：${GO_TARBALL}"
if [ ! -f "${GO_TARBALL}" ]; then
  wget -c "https://golang.google.cn/dl/${GO_TARBALL}"
fi

# 2. 克隆源码并 Vendor 依赖  
echo ">> 克隆源码并 Vendor 依赖"
git clone --depth 1 --branch "v${HEADSCALE_VERSION}" "${GIT_REPO}" headscale-src
cd headscale-src
export GO111MODULE=on
export GOPROXY="https://goproxy.cn,direct"       # 国内代理
export GOSUMDB="sum.golang.google.cn"             # 国内校验库
go mod download
go mod vendor                                   # 打包全部中间文件

# 3. 编译二进制  
echo ">> 编译 headscale 二进制"
go build -mod=vendor -o headscale ./cmd/headscale

# 4. 准备离线目录结构  
cd ..
rm -rf "${OFFLINE_DIR}"
mkdir -p "${OFFLINE_DIR}/usr/local/go" \
         "${OFFLINE_DIR}/usr/local/bin" \
         "${OFFLINE_DIR}/etc/headscale" \
         "${OFFLINE_DIR}/lib/headscale" \
         "${OFFLINE_DIR}/lib/systemd/system"

# 5. 复制文件  
echo ">> 复制 Go 工具链、Headscale 二进制、示例配置和 systemd 文件"
tar -C "${OFFLINE_DIR}/usr/local" -xzf "${GO_TARBALL}" go
cp headscale-src/headscale "${OFFLINE_DIR}/usr/local/bin/"
cp headscale-src/config-example.yaml "${OFFLINE_DIR}/etc/headscale/config.yaml"
cat > "${OFFLINE_DIR}/lib/systemd/system/headscale.service" <<'EOF'
[Unit]
Description=Headscale service
After=network.target

[Service]
ExecStart=/usr/local/bin/headscale serve --config=/etc/headscale/config.yaml
WorkingDirectory=/var/lib/headscale
Restart=on-failure
User=headscale
Group=headscale

[Install]
WantedBy=multi-user.target
EOF

# 6. 打包归档  
echo ">> 创建离线安装包：${ARCHIVE}"
tar -C "${OFFLINE_DIR}" -czf "../${ARCHIVE}" .

echo "离线包生成完毕：../${ARCHIVE}"
