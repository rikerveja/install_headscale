#!/usr/bin/env bash
set -euo pipefail

# —— 动态获取最新 HEADSCALE_VERSION ——  
GIT_SOURCE="https://github.com/juanfont/headscale.git"
LATEST_TAG=$(git ls-remote --tags "${GIT_SOURCE}" \
  | awk -F/ '{print $NF}' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n1)                                     # 使用版本排序取最新 tag :contentReference[oaicite:1]{index=1}
HEADSCALE_VERSION="${LATEST_TAG#v}"
GIT_REPO="${GIT_SOURCE}"

# —— Go 工具链版本 ——  
GO_VERSION="1.24.0"                # 与 go.mod 中版本保持一致  
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"

# —— 输出目录与归档名 ——  
OFFLINE_DIR="headscale-offline"
ARCHIVE="headscale-offline-package.tar.gz"

echo ">> 使用 Headscale 版本：${HEADSCALE_VERSION}"

# 1. 下载并解压 Go 工具链  
echo ">> 准备 Go 工具链：${GO_TARBALL}"
if [ ! -f "${GO_TARBALL}" ]; then
  wget -c "https://golang.google.cn/dl/${GO_TARBALL}"  # 国内镜像下载 :contentReference[oaicite:2]{index=2}
fi

# 解压到本地目录 go-root，并加入 PATH  
if [ ! -d "go-root" ]; then
  tar -xzf "${GO_TARBALL}"            # 解压出目录 `go/` :contentReference[oaicite:3]{index=3}
  mv go go-root
fi
export GOROOT="${PWD}/go-root"
export PATH="${GOROOT}/bin:${PATH}"
echo ">> 已安装 Go 版本：" $(go version)         # 验证 go 可用

# 2. 克隆源码并 Vendor 依赖  
echo ">> 克隆源码并 Vendor 依赖"
git clone --depth 1 --branch "v${HEADSCALE_VERSION}" "${GIT_REPO}" headscale-src
cd headscale-src
export GO111MODULE=on
export GOPROXY="https://goproxy.cn,direct"       # 国内代理
export GOSUMDB="sum.golang.google.cn"             # 国内校验库
go mod download
go mod vendor                                  # 打包全部中间文件

# 3. 编译二进制  
echo ">> 编译 headscale 二进制（显示详细进度）"
go build -mod=vendor -v -o headscale ./cmd/headscale

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
tar -C "${OFFLINE_DIR}/usr/local" -xzf "${GO_TARBALL}" go      # 将 Go 安装包一并打包进离线包
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

echo ">> 离线包生成完毕：../${ARCHIVE}"
