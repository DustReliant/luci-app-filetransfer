#!/bin/bash

# LuCI App File Transfer v1.2.0 一键安装脚本
# 适用于 OpenWRT 系统

set -e

VERSION="1.2.0"
PACKAGE_NAME="luci-app-filetransfer_${VERSION}_all.ipk"
DOWNLOAD_URL="https://github.com/DustReliant/luci-app-filetransfer/releases/download/v${VERSION}/${PACKAGE_NAME}"
SHA256_URL="https://github.com/DustReliant/luci-app-filetransfer/releases/download/v${VERSION}/${PACKAGE_NAME}.sha256"

echo "=========================================="
echo "  LuCI App File Transfer v${VERSION}"
echo "  一键安装脚本"
echo "=========================================="
echo

# 检查是否为OpenWRT系统
if [ ! -f /etc/openwrt_release ]; then
    echo "❌ 错误：此脚本仅适用于 OpenWRT 系统"
    exit 1
fi

echo "✅ 检测到 OpenWRT 系统"

# 显示系统信息
if [ -f /etc/openwrt_release ]; then
    echo "📋 系统信息："
    cat /etc/openwrt_release | grep -E "(DISTRIB_ID|DISTRIB_RELEASE|DISTRIB_DESCRIPTION)" | sed 's/^/   /'
    echo
fi

# 检查网络连接
echo "🌐 检查网络连接..."
if ! ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    echo "❌ 错误：无法连接到互联网，请检查网络设置"
    exit 1
fi
echo "✅ 网络连接正常"

# 创建临时目录
TEMP_DIR="/tmp/luci-app-filetransfer-install"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📥 下载安装包..."
if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$PACKAGE_NAME"; then
    echo "❌ 错误：下载安装包失败"
    exit 1
fi

echo "📥 下载校验和文件..."
if ! wget -q "$SHA256_URL" -O "${PACKAGE_NAME}.sha256"; then
    echo "⚠️  警告：下载校验和文件失败，跳过完整性验证"
else
    echo "🔍 验证文件完整性..."
    if sha256sum -c "${PACKAGE_NAME}.sha256" >/dev/null 2>&1; then
        echo "✅ 文件完整性验证通过"
    else
        echo "❌ 错误：文件完整性验证失败"
        exit 1
    fi
fi

echo "📦 安装应用..."
if opkg install --force-reinstall "$PACKAGE_NAME"; then
    echo "✅ 应用安装成功"
else
    echo "❌ 错误：应用安装失败"
    exit 1
fi

echo "🔄 重启 LuCI 服务..."
if /etc/init.d/uhttpd restart; then
    echo "✅ LuCI 服务重启成功"
else
    echo "⚠️  警告：LuCI 服务重启失败，请手动重启"
fi

# 清理临时文件
cd /
rm -rf "$TEMP_DIR"

echo
echo "=========================================="
echo "🎉 安装完成！"
echo "=========================================="
echo
echo "📍 访问方式："
echo "   1. 打开浏览器访问 LuCI 管理界面"
echo "   2. 登录后导航到：系统 → 文件传输"
echo
echo "🎯 主要功能："
echo "   • 文件传输：上传和下载文件"
echo "   • 文件管理：浏览和管理系统文件"
echo "   • 日志查看：查看应用运行日志"
echo
echo "🔧 调试功能："
echo "   • 按 Ctrl+Shift+E 显示错误日志面板"
echo "   • 支持拖拽上传和文件夹导航"
echo
echo "📖 更多信息请访问："
echo "   https://github.com/DustReliant/luci-app-filetransfer"
echo
echo "感谢使用 LuCI App File Transfer！" 