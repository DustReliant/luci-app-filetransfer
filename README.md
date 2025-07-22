# LuCI App File Transfer

OpenWRT LuCI 文件传输和管理工具，支持文件上传下载、IPK安装和系统文件管理。

## 功能特性

- 📤 文件上传下载
- 📁 文件浏览管理  
- 📦 IPK包安装
- 📊 操作日志查看
- 🔒 安全访问控制

## 编译安装

### 1. 编译环境要求

```bash
# 快速检查（可选）
./check-deps.sh
```

```bash
# Ubuntu/Debian
sudo apt install -y build-essential libncurses5-dev libssl-dev zlib1g-dev

# CentOS/RHEL
sudo yum groupinstall -y "Development Tools"
sudo yum install -y ncurses-devel openssl-devel
```

### 2. 添加到OpenWRT源码

```bash
# 克隆项目到OpenWRT的package目录
cd /path/to/openwrt
git clone https://github.com/DustReliant/luci-app-filetransfer.git package/luci-app-filetransfer

# 更新feeds
./scripts/feeds update -a
./scripts/feeds install -a
```

### 3. 编译

```bash
# 配置编译选项
make menuconfig
# 选择: LuCI -> 3. Applications -> luci-app-filetransfer

# 编译
make package/luci-app-filetransfer/compile V=s
```

### 4. 安装到设备

```bash
# 编译成功后，IPK文件位于：
# bin/packages/*/base/luci-app-filetransfer_1.3.0_all.ipk

# 安装到路由器
scp bin/packages/*/base/luci-app-filetransfer_*.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "opkg install /tmp/luci-app-filetransfer_*.ipk && /etc/init.d/uhttpd restart"
```

## 使用

安装后访问路由器管理界面：**系统 → 文件传输**

## 依赖包

编译时会自动处理以下依赖：
- `luci-base`
- `luci-lib-jsonc` 
- `luci-lib-nixio`

## 配置

默认配置文件：`/etc/config/filetransfer`

```bash
# 修改上传目录
uci set filetransfer.config.upload_dir='/mnt/usb/upload/'

# 修改最大文件大小(MB)
uci set filetransfer.config.max_file_size='200'

# 提交配置
uci commit filetransfer
```

## 许可证

MIT License
