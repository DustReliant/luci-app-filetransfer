# 🎉 LuCI App File Transfer v1.2.0 - 重大功能更新

这是一个重大更新版本，完全重写了文件传输和管理功能，提供更完善和用户友好的文件管理体验。

## 🚀 主要新特性

### 📁 全新文件管理界面
- 🎯 **直观的文件浏览器**：类似本地文件管理器的操作体验
- 🗂️ **文件夹导航**：点击文件夹进入，".." 返回上级目录
- 📍 **地址栏导航**：直接输入路径快速跳转
- ⚡ **实时刷新**：文件列表实时更新

### 📤 完善的文件上传系统
- 🎪 **拖拽上传**：支持文件拖拽到上传区域
- 📊 **进度显示**：实时显示上传进度和状态
- 📦 **多文件上传**：同时上传多个文件
- 🚀 **大文件支持**：优化大文件上传性能

### 🐛 全面的错误监控系统
- 🔍 **自动错误捕获**：JavaScript错误、网络错误自动记录
- 🛠️ **调试面板**：快捷键 `Ctrl+Shift+E` 显示错误日志
- 📝 **详细日志**：记录错误类型、堆栈信息、用户代理等
- 📡 **实时上报**：错误自动记录到系统日志

### 📊 优化的日志系统
- 🎨 **紧凑界面**：优化的日志显示界面，更美观
- 🔍 **搜索过滤**：支持按级别和关键词搜索日志
- ⚡ **实时更新**：日志内容实时刷新
- 💾 **导出功能**：支持日志导出到文件

## 🔧 技术改进

- 🏗️ **架构优化**：前后端分离，清晰的API接口设计
- 🔒 **安全增强**：CSRF保护、权限控制、输入验证
- 🛠️ **调试支持**：提供不需要认证的调试接口
- 📱 **响应式设计**：支持桌面和移动设备

## 📦 快速安装

### 方法1：一键安装脚本（推荐）
```bash
wget -O - https://raw.githubusercontent.com/DustReliant/luci-app-filetransfer/master/install.sh | sh
```

### 方法2：手动安装
```bash
# 下载安装包
wget https://github.com/DustReliant/luci-app-filetransfer/releases/download/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk

# 验证完整性（可选）
wget https://github.com/DustReliant/luci-app-filetransfer/releases/download/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk.sha256
sha256sum -c luci-app-filetransfer_1.2.0_all.ipk.sha256

# 安装
opkg install luci-app-filetransfer_1.2.0_all.ipk

# 重启LuCI服务
/etc/init.d/uhttpd restart
```

## 📋 系统要求

- OpenWRT 21.02 或更高版本
- LuCI 18.06 或更高版本
- 至少 1MB 可用存储空间

## 🎯 使用方法

1. 登录 LuCI 管理界面
2. 导航到 **系统 → 文件传输**
3. 选择功能页面：
   - **文件传输**：上传和下载文件
   - **文件管理**：浏览和管理系统文件
   - **日志查看**：查看应用日志

## 📁 文件信息

- **安装包**: `luci-app-filetransfer_1.2.0_all.ipk` (21KB)
- **SHA256**: `6ac697175e78c556181ec1834586ac62b9a7f13578917d387b1ff2f865d2caaf`

## 🔄 完整更新日志

查看完整的更新日志和技术细节，请参阅 [RELEASE_NOTES.md](https://github.com/DustReliant/luci-app-filetransfer/blob/master/releases/v1.2.0/RELEASE_NOTES.md)

## 🐛 问题反馈

如果您在使用过程中遇到问题，请在 [Issues](https://github.com/DustReliant/luci-app-filetransfer/issues) 页面反馈。

---

**感谢使用 LuCI App File Transfer！如果这个项目对您有帮助，请给个 ⭐ 支持！** 