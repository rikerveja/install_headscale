# install_headscale
执行完上述脚本后，Headscale 将在 /usr/local/bin/headscale 可用，配置文件在 /etc/headscale/config.yaml，数据目录在 /var/lib/headscale，并由 systemd 管理。

# package_headscale.sh
说明：

使用 Gitee 镜像避免 GitHub 访问失败 
Gitee

通过 go mod vendor 将所有依赖复制到 vendor/ 目录，实现真正的离线构建 
Go

配置国内 Go 代理和校验库，保障模块下载和校验正常


下面以一个典型流程说明，如何在本地一键打包、上传并在云服务器上一键执行安装脚本，实现 Headscale 离线部署。

> **概括**  
> 1. **本地生成离线包**：运行 `package_headscale.sh`，在本地输出 `headscale-offline-package.tar.gz`（含 Go 工具链、Headscale 二进制、示例配置、systemd 文件）citeturn0search0turn0search1。  
> 2. **上传到云服务器**：使用 `scp` 将打包好的离线包和安装脚本 `install_headscale.sh` 一次性拷贝到目标服务器citeturn1search0。  
> 3. **远程一键安装**：SSH 登录云服务器，赋予安装脚本可执行权限并执行，即可自动完成解压、用户创建、权限设置、systemd 启动等全部步骤。  

---

## 前提条件

- **本地环境**：已具备 Linux 或 macOS 终端，能执行 `bash`、`git`、`go`、`tar`、`wget` 等命令；已将前文脚本 `package_headscale.sh` 与 `install_headscale.sh` 放在同一目录。  
- **云服务器**：已开通 SSH 登录账号（如 `root` 或具备 `sudo` 权限的用户），防火墙允许 22 端口访问。  
- **网络**：本地可访问 GitHub/Gitee 和 Go 代理（用于离线包生成）；云服务器无需外网访问。  

---

## 操作步骤

### 1\. 本地生成离线包

在脚本所在目录运行：
```bash
chmod +x package_headscale.sh
./package_headscale.sh
```
- 完成后会在上级目录生成 `headscale-offline-package.tar.gz`，包含 Go 工具链与 Headscale 所有依赖及配置citeturn0search0turn0search1。

### 2\. 上传文件到云服务器

利用 `scp` 一次性将离线包与安装脚本传至服务器家目录：
```bash
scp headscale-offline-package.tar.gz install_headscale.sh user@SERVER_IP:~
```
- `user@SERVER_IP` 替换为你的登录用户名和服务器 IP 地址或域名。  
- 如果需要保留文件属性，可加上 `-p`；若目录较多，也可用 `-r` 递归复制目录citeturn1search0。

### 3\. 云服务器上一键安装

SSH 登录到服务器后，执行：
```bash
ssh user@SERVER_IP

# 在服务器上：
chmod +x install_headscale.sh
sudo bash ./install_headscale.sh
```
- 脚本会自动完成：  
  1. 解压 `/headscale-offline-package.tar.gz` 到 `/usr/local`、`/etc/headscale`、`/lib/systemd/system`；  
  2. 创建 `headscale` 系统用户及数据目录 `/var/lib/headscale`；  
  3. 设置目录权限；  
  4. 加载并启动 `headscale.service`。  
- 全程无需手动编辑或下载任何外部依赖，执行完毕后即可开始使用 Headscale。  

---

### 小贴士

- 若你的服务器账号非 `root`，请确保脚本执行时使用 `sudo`。  
- 如需调整配置（如数据库路径、ACL、日志级别等），可在 `/etc/headscale/config.yaml` 中修改后重启服务：  
  ```bash
  sudo systemctl restart headscale
  ```  
- 若云服务器上已有 Docker 环境，也可改用前文「Docker 多阶段构建 + 离线镜像导出/加载」方案。  

通过上述流程，即可实现「本地一键打包 → 上传 → 云服务器一键安装」的全自动离线部署 Headscale。