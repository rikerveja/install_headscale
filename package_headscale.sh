#!/usr/bin/env bash
set -euo pipefail

# —— 配置变量 ——  
HEADSCALE_VERSION="0.25.1"        # 目标版本  
GIT_REPO="https://gitee.com/mirrors_tianon/headscale.git"  # Gitee 镜像 :contentReference[oaicite:3]{index=3}  
GO_VERSION="1.24.0"                # 与 go.mod 中版本保持一致 :contentReference[oaicite:4]{index=4}  
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"  
OFFLINE_DIR="headscale-offline"  
ARCHIVE="headscale-offline-package.tar.gz"

# 1. 准备 Go 工具链  
echo ">> 准备 Go 工具链：${GO_TARBALL}"  
if [ ! -f "${GO_TARBALL}" ]; then
  wget -c "https://golang.google.cn/dl/${GO_TARBALL}"  # 可切换到国内镜像
fi

# 2. 克隆源码并 Vendor 依赖  
echo ">> 克隆源码并 Vendor 依赖"  
git clone --depth 1 --branch "v${HEADSCALE_VERSION}" "${GIT_REPO}" headscale-src  
cd headscale-src  
export GO111MODULE=on  
export GOPROXY="https://goproxy.cn,direct"            # 国内代理 :contentReference[oaicite:5]{index=5}  
export GOSUMDB="sum.golang.google.cn"                  # 国内校验库 :contentReference[oaicite:6]{index=6}  
go mod download  
go mod vendor                                          # 打包全部中间文件 :contentReference[oaicite:7]{index=7}  

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
