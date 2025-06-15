# LuCI File Transfer

[![GitHub stars](https://img.shields.io/github/stars/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=4CAF50&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub forks](https://img.shields.io/github/forks/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=FF9800&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)
[![GitHub license](https://img.shields.io/github/license/DustReliant/luci-app-filetransfer?style=flat-square&labelColor=9C27B0&color=2196F3&logo=github)](https://github.com/DustReliant/luci-app-filetransfer)

一个用于 OpenWrt 的文件传输管理系统插件，提供直观的 Web 界面进行文件上传、下载和管理操作。

## 功能特点

- 文件上传（支持拖拽）
- 文件下载
- 文件管理（列表、删除）
- 操作日志记录
- 系统设置
- 支持多种文件类型
- 安全保护（CSRF、SSL）
- 响应式设计

## 安装方法

1. 在 OpenWrt 的软件包管理器中搜索 `luci-app-filetransfer`
2. 点击安装

或者通过命令行安装：

```bash
opkg update
opkg install luci-app-filetransfer
```

## 使用方法

1. 登录 OpenWrt 的 Web 界面
2. 在系统菜单中找到"文件传输"
3. 使用界面进行文件操作

## 配置说明

配置文件位于 `/etc/config/filetransfer`，可以修改以下选项：

- 上传目录
- 最大文件大小
- 允许的文件类型
- 日志级别
- 日志保留时间
- 安全设置

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 作者

- DustReliant

## 贡献

欢迎提交 Issue 和 Pull Request。

## 致谢

感谢所有为本项目做出贡献的开发者。

## 系统要求
- OpenWrt 19.07 或更高版本
- LuCI 界面
- 至少 1MB 可用存储空间
- 支持的文件系统：ext4, jffs2, squashfs

## 注意事项
- 建议定期清理上传目录
- 大文件传输时注意设备存储空间
- 建议使用有线网络进行大文件传输
- 定期检查文件权限设置
- 定期备份重要操作日志

## 常见问题
1. 上传失败
   - 检查存储空间
   - 验证文件大小是否超限
   - 确认文件类型是否允许
   - 查看操作日志了解具体原因

2. 下载失败
   - 检查网络连接
   - 确认文件是否存在
   - 验证存储空间
   - 查看操作日志了解具体原因

## 更新日志
### v1.1.0 (2024-03-xx)
- 添加操作日志功能
- 优化界面设计
- 添加拖拽上传支持
- 改进文件操作反馈
- 增加日志导出功能

### v1.0.0 (2024-11-xx)
- 初始版本发布
- 实现基本文件上传下载功能
- 添加文件管理功能
- 实现 CSRF 防护

## 贡献指南
欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。




