# LuCI File Transfer

[![GitHub stars](https://img.shields.io/github/stars/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=4CAF50&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub forks](https://img.shields.io/github/forks/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=FF9800&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub license](https://img.shields.io/github/license/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=9C27B0&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)

一个用于 OpenWrt 的文件传输管理系统插件，提供直观的 Web 界面进行文件上传、下载和管理操作。

## 功能特点

### 核心功能
- **文件上传**：支持拖拽上传、多文件上传、进度条显示
- **文件下载**：一键下载、进度反馈
- **文件管理**：文件列表、搜索、排序、删除操作
- **批量操作**：支持多选文件进行批量删除、下载
- **文件预览**：支持文本文件在线预览

### 日志系统
- **操作日志**：记录所有文件操作行为
- **日志筛选**：按级别（INFO/WARNING/ERROR）筛选
- **日志搜索**：关键词搜索日志内容
- **日志导出**：支持TXT/JSON格式导出
- **日志清空**：一键清空日志记录

### 安全特性
- **CSRF防护**：防止跨站请求伪造攻击
- **文件类型限制**：只允许安全文件类型上传
- **文件大小限制**：防止大文件占用存储空间
- **文件名安全处理**：防止路径遍历攻击
- **SSL支持**：可配置HTTPS传输

### 界面特性
- **响应式设计**：适配各种屏幕尺寸
- **现代化UI**：美观的界面设计和动画效果
- **操作提示**：按钮悬浮提示、操作反馈
- **文件类型图标**：直观显示文件类型
- **深色模式适配**：支持系统主题切换

### 系统管理
- **IPK安装**：支持直接安装上传的IPK包
- **系统设置**：可配置上传目录、文件大小限制等
- **多语言支持**：中文、英文界面
- **权限管理**：细粒度权限控制

## 安装方法

### 方法一：软件包管理器
1. 在 OpenWrt 的软件包管理器中搜索 `luci-app-filetransfer`
2. 点击安装

### 方法二：命令行安装
```bash
opkg update
opkg install luci-app-filetransfer
```

### 方法三：手动安装
```bash
# 下载IPK包
wget https://github.com/DustReliant/luci-app-filetransfer/releases/download/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk

# 安装主程序
opkg install luci-app-filetransfer_1.2.0_all.ipk

# 安装语言包（可选）
opkg install luci-i18n-filetransfer-zh-cn_1.2.0_all.ipk
opkg install luci-i18n-filetransfer-en_1.2.0_all.ipk
```

## 使用方法

### 基本操作
1. 登录 OpenWrt 的 Web 界面
2. 在系统菜单中找到"文件传输"
3. 使用界面进行文件操作

### 文件上传
- **拖拽上传**：直接将文件拖拽到上传区域
- **点击上传**：点击上传按钮选择文件
- **多文件上传**：支持同时选择多个文件
- **进度显示**：实时显示上传进度

### 文件管理
- **文件列表**：查看所有上传的文件
- **搜索文件**：输入关键词快速查找
- **文件排序**：按名称、大小、时间排序
- **批量操作**：选择多个文件进行批量操作

### 日志查看
- **实时日志**：查看系统操作日志
- **级别筛选**：按日志级别筛选显示
- **关键词搜索**：搜索特定日志内容
- **日志导出**：导出日志文件

## 配置说明

配置文件位于 `/etc/config/filetransfer`，可以修改以下选项：

### 基本设置
- `upload_dir`：上传目录路径（默认：/tmp/upload/）
- `max_file_size`：最大文件大小，单位MB（默认：50）
- `allowed_extensions`：允许的文件类型（默认：ipk,tar,gz,zip,txt,conf,json）

### 日志设置
- `log_level`：日志级别（info/warning/error/debug）
- `log_retention`：日志保留天数（默认：7）
- `auto_clean`：自动清理旧日志（1/0）

### 安全设置
- `enable_csrf`：启用CSRF防护（1/0）
- `enable_ssl`：启用SSL传输（1/0）
- `allowed_ips`：允许访问的IP地址（留空表示允许所有）

## 系统要求

- **OpenWrt版本**：19.07 或更高版本
- **LuCI界面**：需要LuCI Web界面
- **存储空间**：至少 1MB 可用存储空间
- **文件系统**：支持 ext4, jffs2, squashfs
- **内存要求**：至少 32MB 可用内存
- **网络要求**：支持HTTP/HTTPS协议

## 注意事项

### 安全建议
- 建议定期清理上传目录
- 大文件传输时注意设备存储空间
- 建议使用有线网络进行大文件传输
- 定期检查文件权限设置
- 定期备份重要操作日志
- 建议启用SSL传输保护数据安全

### 性能优化
- 大文件传输时建议关闭其他占用带宽的应用
- 定期清理临时文件和日志文件
- 合理设置文件大小限制
- 监控系统资源使用情况

## 常见问题

### 1. 上传失败
**可能原因：**
- 存储空间不足
- 文件大小超过限制
- 文件类型不被允许
- 权限设置问题

**解决方法：**
- 检查存储空间：`df -h`
- 验证文件大小是否超限
- 确认文件类型是否在允许列表中
- 查看操作日志了解具体原因
- 检查目录权限：`ls -la /tmp/upload/`

### 2. 下载失败
**可能原因：**
- 网络连接问题
- 文件不存在
- 存储空间不足
- 权限问题

**解决方法：**
- 检查网络连接：`ping 8.8.8.8`
- 确认文件是否存在：`ls -la /tmp/upload/`
- 验证存储空间
- 查看操作日志了解具体原因

### 3. 界面无法访问
**可能原因：**
- 插件未正确安装
- LuCI服务未启动
- 防火墙阻止访问

**解决方法：**
- 检查插件安装：`opkg list-installed | grep filetransfer`
- 重启LuCI服务：`/etc/init.d/uhttpd restart`
- 检查防火墙设置
- 查看系统日志：`logread`

### 4. 日志功能异常
**可能原因：**
- 日志文件权限问题
- 存储空间不足
- 日志级别设置不当

**解决方法：**
- 检查日志文件权限：`ls -la /tmp/filetransfer.log`
- 清理存储空间
- 调整日志级别设置
- 重启服务：`/etc/init.d/filetransfer restart`

## 更新日志

### v1.2.0 (2024-06-26)
- **修复**：修复控制器未定义函数导致的报错
- **优化**：优化主界面布局与交互体验
- **新增**：日志模块支持级别筛选、导出、清空功能
- **改进**：文件上传/下载进度条优化
- **新增**：批量操作功能（多选删除/下载）
- **新增**：操作按钮悬浮提示
- **优化**：代码结构优化，提升健壮性
- **完善**：多语言支持，国际化改进
- **新增**：文件类型图标显示
- **改进**：响应式设计，适配移动设备

### v1.1.0 (2024-03-xx)
- **新增**：操作日志功能
- **优化**：界面设计，现代化UI
- **新增**：拖拽上传支持
- **改进**：文件操作反馈机制
- **新增**：日志导出功能
- **优化**：文件管理界面

### v1.0.0 (2024-11-xx)
- **初始版本**：基本文件上传下载功能
- **新增**：文件管理功能
- **实现**：CSRF防护机制
- **新增**：基础设置界面

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 作者

- **DustReliant** - 项目维护者

## 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

### 贡献指南
1. Fork 本项目
2. 创建功能分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送分支：`git push origin feature/AmazingFeature`
5. 提交 Pull Request

### 问题反馈
- 使用 [GitHub Issues](https://github.com/DustReliant/luci-app-filetransfer/issues) 报告问题
- 提供详细的错误信息和复现步骤
- 包含系统版本和插件版本信息

## 致谢

感谢所有为本项目做出贡献的开发者，特别感谢：
- OpenWrt 社区
- LuCI 开发团队
- 所有测试用户和反馈者

## 相关链接

- [项目主页](https://github.com/DustReliant/luci-app-filetransfer)
- [问题反馈](https://github.com/DustReliant/luci-app-filetransfer/issues)
- [OpenWrt官网](https://openwrt.org/)
- [LuCI文档](https://openwrt.org/docs/guide-user/luci/start)




