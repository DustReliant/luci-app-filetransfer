# LuCI App File Transfer

[![GitHub stars](https://img.shields.io/github/stars/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=4CAF50&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub forks](https://img.shields.io/github/forks/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=FF9800&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub license](https://img.shields.io/github/license/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=9C27B0&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)

一个功能完善的 OpenWRT LuCI 文件传输和管理应用，提供直观的文件上传、下载和管理功能。

## 🌟 主要特性

### 📁 文件管理
- **直观的文件浏览器**：类似本地文件管理器的操作体验
- **文件夹导航**：点击文件夹进入，".." 返回上级目录  
- **地址栏导航**：直接输入路径快速跳转
- **文件操作**：下载、删除、预览文件

### 📤 文件上传
- **拖拽上传**：支持文件拖拽到上传区域
- **进度显示**：实时显示上传进度和状态
- **多文件上传**：同时上传多个文件
- **大文件支持**：优化大文件上传性能

### 🐛 错误监控
- **自动错误捕获**：JavaScript错误、网络错误自动记录
- **调试面板**：快捷键 Ctrl+Shift+E 显示错误日志
- **详细日志**：记录错误类型、堆栈信息、用户代理等
- **实时上报**：错误自动记录到系统日志

### 📊 日志系统
- **实时日志显示**：应用运行日志实时更新
- **搜索过滤**：支持按级别和关键词搜索日志
- **紧凑界面**：优化的日志显示界面
- **导出功能**：支持日志导出到文件

## 🚀 快速安装

### 安装前检查

在开始安装前，请确保系统满足要求：

```bash
# 检查OpenWRT版本
cat /etc/openwrt_release

# 检查可用存储空间
df -h /

# 检查内存使用情况
free -h

# 检查LuCI是否正常运行
/etc/init.d/uhttpd status

# 检查必需依赖包
opkg list-installed | grep -E "(luci-base|luci-lib|nixio|uhttpd)"
```

### 方法1：一键安装脚本（推荐）

在 OpenWRT 设备上运行：

```bash
# 下载并运行安装脚本
wget -O - https://raw.githubusercontent.com/DustReliant/luci-app-filetransfer/main/install.sh | sh

# 或者分步执行
wget https://raw.githubusercontent.com/DustReliant/luci-app-filetransfer/main/install.sh
chmod +x install.sh
./install.sh
```

### 方法2：手动安装

1. **下载安装包**
   ```bash
   wget https://github.com/DustReliant/luci-app-filetransfer/releases/download/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk
   ```

2. **安装应用**
   ```bash
   opkg install luci-app-filetransfer_1.2.0_all.ipk
   ```

3. **安装依赖包（如果需要）**
   ```bash
   # 更新包列表
   opkg update
   
   # 安装必需依赖
   opkg install luci-lib-jsonc nixio
   ```

4. **重启LuCI服务**
   ```bash
   /etc/init.d/uhttpd restart
   ```

5. **验证安装**
   ```bash
   # 检查服务状态
   /etc/init.d/filetransfer status
   
   # 检查日志
   tail -f /tmp/filetransfer.log
   ```

### 方法3：从源码编译

适用于开发者或需要自定义功能的用户：

#### 快速环境检查

我们提供了一个便捷的检查脚本：

```bash
# 下载并运行环境检查脚本
wget https://raw.githubusercontent.com/DustReliant/luci-app-filetransfer/main/scripts/check-build-deps.sh
chmod +x check-build-deps.sh
./check-build-deps.sh
```

#### 编译环境要求

**主机系统要求：**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
    python3-distutils rsync unzip zlib1g-dev file wget

# CentOS/RHEL/Fedora  
sudo yum groupinstall -y "Development Tools"
sudo yum install -y ncurses-devel openssl-devel git wget which flex bison

# Arch Linux
sudo pacman -S base-devel ncurses openssl git wget which flex bison
```

**OpenWRT SDK环境：**
```bash
# 1. 下载对应架构的SDK（以mipsel为例）
wget https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt7621/openwrt-sdk-22.03.5-ramips-mt7621_gcc-11.2.0_musl.Linux-x86_64.tar.xz
tar -xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# 2. 更新feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 安装编译依赖包
./scripts/feeds install luci-base luci-lib-jsonc nixio
```

#### 完整编译流程

```bash
# 1. 准备OpenWRT编译环境
git clone https://github.com/openwrt/openwrt.git
cd openwrt

# 2. 更新feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 安装必需依赖包
./scripts/feeds install luci-base luci-lib-base luci-lib-jsonc nixio uhttpd

# 4. 添加本项目到package目录
git clone https://github.com/DustReliant/luci-app-filetransfer.git package/luci-app-filetransfer

# 5. 配置编译选项
make menuconfig
# 导航到: LuCI -> 3. Applications -> 选择 luci-app-filetransfer
# 同时确保选择了以下依赖：
# - LuCI -> 1. Collections -> luci-base
# - LuCI -> 5. Libraries -> luci-lib-jsonc
# - Libraries -> nixio

# 6. 编译（使用并行编译加速）
make package/luci-app-filetransfer/compile V=s -j$(nproc)

# 7. 安装编译好的包
scp bin/packages/*/luci/luci-app-filetransfer_*.ipk root@router-ip:/tmp/
ssh root@router-ip "opkg install /tmp/luci-app-filetransfer_*.ipk"
```

#### 编译依赖包列表

**核心依赖（必需）：**
```bash
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-lib-jsonc=y  # 或 luci-lib-json
CONFIG_PACKAGE_nixio=y
CONFIG_PACKAGE_uhttpd=y
```

**可选依赖（增强功能）：**
```bash
CONFIG_PACKAGE_luci-lib-base=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_file=y  # 文件类型检测
CONFIG_PACKAGE_libustream-openssl=y  # SSL支持
```

#### 交叉编译注意事项

```bash
# 确保目标架构正确配置
make menuconfig
# Target System -> 选择你的硬件平台
# Target Profile -> 选择具体设备型号

# 如果遇到依赖问题，强制重新编译依赖
make package/luci-lib-jsonc/clean
make package/luci-lib-jsonc/compile
make package/nixio/clean  
make package/nixio/compile

# 清理和重新编译本包
make package/luci-app-filetransfer/clean
make package/luci-app-filetransfer/compile V=s
```

## 🔧 故障排除

### 常见问题

#### 1. 安装失败
```bash
# 检查依赖
opkg list-installed | grep luci-lib

# 如果缺少依赖，手动安装
opkg update
opkg install luci-lib-jsonc luci-lib-base

# 重新安装
opkg remove luci-app-filetransfer
opkg install luci-app-filetransfer_*.ipk
```

#### 2. 界面无法访问
```bash
# 重启LuCI服务
/etc/init.d/uhttpd restart

# 检查端口占用
netstat -tlnp | grep :80

# 清除浏览器缓存并重新访问
```

#### 3. 文件上传失败
```bash
# 检查上传目录权限
ls -la /tmp/upload/
chmod 755 /tmp/upload/

# 检查磁盘空间
df -h /tmp

# 查看错误日志
tail -f /tmp/filetransfer.log
```

#### 4. CSRF保护错误
```bash
# 检查配置
uci show filetransfer.config.enable_csrf

# 临时禁用CSRF（仅用于调试）
uci set filetransfer.config.enable_csrf='0'
uci commit filetransfer
/etc/init.d/uhttpd restart
```

### 调试模式

启用详细日志记录：

```bash
# 设置调试级别
uci set filetransfer.config.log_level='debug'
uci commit filetransfer

# 查看实时日志
tail -f /tmp/filetransfer.log
```

## 📋 系统要求

### 基本要求
- **OpenWRT**: 21.02 或更高版本（推荐 22.03+）
- **LuCI**: 18.06 或更高版本
- **存储空间**: 至少 5MB 可用存储空间
- **内存**: 至少 64MB RAM（推荐 128MB+）

### 依赖包

#### 必需依赖
```bash
# 核心依赖（通常已预装）
opkg install luci-base
opkg install luci-lib-base
opkg install luci-lib-jsonc  # 或 luci-lib-json
opkg install uhttpd

# 文件系统支持
opkg install nixio
```

#### 可选依赖（增强功能）
```bash
# 增强的JSON支持
opkg install luci-lib-jsonc

# 文件类型检测
opkg install file

# 增强的SSL支持
opkg install libustream-openssl  # 或 libustream-mbedtls
```

### 硬件要求

| 设备类型 | 最低要求 | 推荐配置 |
|---------|---------|---------|
| **路由器** | 8MB Flash, 64MB RAM | 16MB Flash, 128MB RAM |
| **单板计算机** | 16MB Flash, 128MB RAM | 32MB Flash, 256MB RAM |
| **x86设备** | 64MB Flash, 256MB RAM | 128MB Flash, 512MB RAM |

### 网络要求
- HTTP/HTTPS 访问端口（通常80/443）
- 管理员权限访问LuCI界面

## 🎯 使用指南

### 访问应用
1. 登录 LuCI 管理界面
2. 导航到 **系统 → 文件传输**
3. 选择功能页面：
   - **文件传输**：上传和下载文件
   - **文件管理**：浏览和管理系统文件
   - **日志查看**：查看应用日志

### 主要功能

#### 文件上传
- 点击上传区域选择文件，或直接拖拽文件
- 支持单个或多个文件同时上传
- 实时显示上传进度和状态

#### 文件管理
- 在地址栏输入路径直接跳转（如 `/etc`、`/tmp`）
- 点击文件夹进入子目录
- 点击 ".." 返回上级目录
- 下载或删除文件

#### 错误监控
- 按 `Ctrl+Shift+E` 显示错误日志面板
- 自动捕获页面错误并记录
- 支持手动刷新和清除错误日志

## 🔧 开发和编译

### 开发环境设置

1. **克隆仓库**
   ```bash
   git clone https://github.com/DustReliant/luci-app-filetransfer.git
   cd luci-app-filetransfer
   ```

2. **设置OpenWRT编译环境**
   ```bash
   # 将项目放到OpenWRT源码的package目录下
   ln -s $(pwd) /path/to/openwrt/package/luci-app-filetransfer
   ```

3. **编译**
   ```bash
   cd /path/to/openwrt
   make package/luci-app-filetransfer/compile V=s
   ```

### 开发脚本

项目包含便捷的开发脚本：

- `deploy_and_test.sh`：编译、部署和测试脚本
- `quick_test.sh`：快速测试脚本
- `install.sh`：一键安装脚本

## 📁 项目结构

```
luci-app-filetransfer/
├── luasrc/
│   ├── controller/
│   │   └── filetransfer.lua      # 控制器和API
│   ├── model/cbi/
│   │   └── filetransfer.lua      # 配置界面
│   └── view/filetransfer/
│       ├── main.htm              # 主页面（文件上传）
│       ├── manage.htm            # 文件管理页面
│       └── log.htm               # 日志查看页面
├── root/
│   ├── etc/config/filetransfer   # 配置文件
│   ├── etc/init.d/filetransfer   # 初始化脚本
│   └── usr/share/filetransfer/   # 共享文件
├── po/                           # 多语言支持
├── releases/                     # 发布文件
├── Makefile                      # OpenWRT编译配置
├── install.sh                    # 一键安装脚本
└── README.md                     # 项目说明
```

## ⚙️ 高级配置

### 安全配置

#### CSRF保护
```bash
# 启用CSRF保护（推荐）
uci set filetransfer.config.enable_csrf='1'
uci commit filetransfer
```

#### IP白名单
```bash
# 限制访问IP地址（可选）
uci set filetransfer.config.allowed_ips='192.168.1.100,192.168.1.101'
uci commit filetransfer
```

#### 文件验证
```bash
# 启用文件内容验证
uci set filetransfer.config.enable_file_validation='1'
uci commit filetransfer
```

### 性能优化

#### 上传设置
```bash
# 调整最大文件大小（MB）
uci set filetransfer.config.max_file_size='200'

# 设置并发上传会话数
uci set filetransfer.config.max_upload_sessions='10'

# 设置会话超时时间（秒）
uci set filetransfer.config.session_timeout='7200'

uci commit filetransfer
```

#### 存储配置
```bash
# 更改上传目录（确保有足够空间）
uci set filetransfer.config.upload_dir='/mnt/usb/upload/'
uci commit filetransfer

# 创建新目录并设置权限
mkdir -p /mnt/usb/upload/
chmod 755 /mnt/usb/upload/
```

#### 日志管理
```bash
# 设置日志级别
uci set filetransfer.config.log_level='warning'  # debug|info|warning|error

# 设置日志保留天数
uci set filetransfer.config.log_retention='14'

# 启用自动清理
uci set filetransfer.config.auto_clean='1'

uci commit filetransfer
```

### 自定义文件类型

添加支持的文件类型：

```bash
# 查看当前支持的类型
uci get filetransfer.config.allowed_extensions

# 添加新的文件类型
uci set filetransfer.config.allowed_extensions='ipk,tar,gz,zip,txt,conf,json,bin,img,sig,deb,rpm,apk,dmg'
uci commit filetransfer
```

### SSL/HTTPS 配置

```bash
# 启用SSL支持
uci set filetransfer.config.enable_ssl='1'
uci commit filetransfer

# 配置uhttpd使用HTTPS
uci set uhttpd.main.listen_https='0.0.0.0:443'
uci set uhttpd.main.cert='/etc/ssl/certs/uhttpd.crt'
uci set uhttpd.main.key='/etc/ssl/private/uhttpd.key'
uci commit uhttpd
/etc/init.d/uhttpd restart
```

## 🔄 更新日志

### v1.3.0 (2024-12-XX) - 安全和性能大幅提升 🚀
- 🔒 **安全强化**：
  - 完善的CSRF保护机制，支持多种token验证方式
  - IP白名单访问控制
  - 增强的文件名安全验证，防止路径遍历攻击
  - 文件内容验证（魔数检查）
  - 统一的错误处理和安全日志记录

- ⚡ **性能优化**：
  - 使用nixio.fs替代shell命令，大幅提升文件操作性能
  - 优化的文件列表获取算法
  - 改进的大文件上传处理
  - 减少内存占用和提高响应速度

- 🛠️ **配置管理**：
  - 完整的UCI配置支持
  - 动态配置加载，无需重启服务
  - 新增多项可配置参数（并发会话、超时设置等）
  - 扩展的文件类型支持

- 📊 **日志系统**：
  - 结构化日志记录
  - 可配置的日志级别（debug/info/warning/error）
  - 上下文信息记录
  - 自动日志清理功能

- 🔧 **代码质量**：
  - 统一的错误响应格式
  - 模块化的功能设计
  - 改进的代码注释和文档
  - 更好的错误处理机制

### v1.2.0 (2024-06-29) - 重大更新
- 🎉 **重大更新**：完全重写文件传输和管理功能
- ✨ **新增**：全新的文件管理界面，支持文件夹导航
- ✨ **新增**：完整的错误监控系统，自动捕获和记录错误
- ✨ **新增**：优化的日志系统界面，紧凑美观
- 🔧 **改进**：文件上传性能和用户体验
- 🔧 **改进**：前端界面设计和响应式布局
- 🔒 **安全**：增强CSRF保护和权限控制
- 🐛 **修复**：多个稳定性和兼容性问题

### v1.1.0
- 基础文件传输功能
- 简单的文件管理
- 基本的日志记录

## 📚 API 文档

### REST API 接口

应用提供以下API接口供开发者使用：

#### 文件上传
```
POST /cgi-bin/luci/admin/system/filetransfer/upload
Content-Type: multipart/form-data

Headers:
  X-CSRF-Token: <token>  # 可选，如果启用CSRF保护

Response:
{
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "filename": "example.ipk",
    "size": 1024,
    "path": "/tmp/upload/example.ipk"
  },
  "timestamp": 1640995200
}
```

#### 文件列表
```
GET /cgi-bin/luci/admin/system/filetransfer/list

Response:
{
  "success": true,
  "data": {
    "files": [
      {
        "name": "example.ipk",
        "size": "1024",
        "date": "12-31 23:59",
        "mtime": 1640995200
      }
    ]
  }
}
```

#### 文件删除
```
POST /cgi-bin/luci/admin/system/filetransfer/delete
Content-Type: application/x-www-form-urlencoded

Body: filename=example.ipk&csrf_token=<token>

Response:
{
  "success": true,
  "message": "File deleted successfully",
  "data": {
    "filename": "example.ipk"
  }
}
```

#### 错误响应格式
```json
{
  "error": true,
  "code": "ERROR_CODE",
  "message": "Human readable error message",
  "details": "Additional error details",
  "timestamp": 1640995200
}
```

### 错误代码

| 错误代码 | 说明 | HTTP状态码 |
|---------|------|-----------|
| `CSRF_FAILED` | CSRF令牌验证失败 | 403 |
| `IP_BLOCKED` | IP地址未在白名单中 | 403 |
| `MISSING_FILENAME` | 缺少文件名参数 | 400 |
| `INVALID_FILENAME` | 无效的文件名 | 400 |
| `INVALID_FILE_TYPE` | 不支持的文件类型 | 400 |
| `FILE_NOT_FOUND` | 文件不存在 | 404 |
| `INSTALL_FAILED` | IPK安装失败 | 500 |
| `DELETE_FAILED` | 文件删除失败 | 500 |

## 🐛 已知问题和限制

### 已知问题
- **旧版本兼容性**：在OpenWRT 19.07及更早版本上可能需要手动安装依赖包
- **大文件上传**：超过可用内存的文件可能导致上传失败（建议分块上传）
- **移动设备**：某些移动浏览器的拖拽功能可能受限

### 当前限制
- **并发限制**：默认最多支持5个并发上传会话
- **文件大小**：单文件最大100MB（可配置）
- **文件类型**：仅支持预定义的文件类型（可扩展）
- **存储位置**：默认使用`/tmp/upload/`，重启后文件可能丢失

### 解决方案
```bash
# 1. 增加并发会话数
uci set filetransfer.config.max_upload_sessions='10'

# 2. 调整文件大小限制
uci set filetransfer.config.max_file_size='200'

# 3. 更改为持久存储
uci set filetransfer.config.upload_dir='/mnt/storage/upload/'

# 4. 添加自定义文件类型
uci set filetransfer.config.allowed_extensions='ipk,tar,gz,zip,txt,conf,json,custom'

uci commit filetransfer
/etc/init.d/uhttpd restart
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📞 支持

如果您在使用过程中遇到问题或有建议：

- **GitHub Issues**: [https://github.com/DustReliant/luci-app-filetransfer/issues](https://github.com/DustReliant/luci-app-filetransfer/issues)
- **项目主页**: [https://github.com/DustReliant/luci-app-filetransfer](https://github.com/DustReliant/luci-app-filetransfer)

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🙏 致谢

感谢所有为这个项目做出贡献的开发者和用户！

---

**⭐ 如果这个项目对您有帮助，请给个星标支持！**


