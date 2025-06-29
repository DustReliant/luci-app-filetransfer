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

### 方法1：一键安装脚本（推荐）

在 OpenWRT 设备上运行：

```bash
wget -O - https://raw.githubusercontent.com/DustReliant/luci-app-filetransfer/master/install.sh | sh
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

3. **重启LuCI服务**
   ```bash
   /etc/init.d/uhttpd restart
   ```

## 📋 系统要求

- OpenWRT 21.02 或更高版本
- LuCI 18.06 或更高版本
- 至少 1MB 可用存储空间

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

## 🔄 更新日志

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

## 🐛 已知问题

- 在某些旧版本的 OpenWRT 上可能需要手动重启服务
- 大文件上传时建议保持网络连接稳定
- 移动设备上的拖拽功能可能有限制

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


