#!/bin/bash

# OpenWRT LuCI-App-FileTransfer 编译环境检查脚本
echo "========================================"
echo "OpenWRT LuCI-App-FileTransfer 编译环境检查"  
echo "========================================"

# 检查基本工具
echo "检查编译工具..."
tools=("gcc" "g++" "make" "git" "wget" "flex" "bison")
missing=0

for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✓ $tool"
    else
        echo "✗ $tool (缺失)"
        missing=1
    fi
done

echo ""
echo "依赖安装建议："
echo "Ubuntu/Debian:"
echo "sudo apt install -y build-essential libncurses5-dev libssl-dev zlib1g-dev gcc-multilib"
echo ""
echo "CentOS/RHEL:"
echo "sudo yum groupinstall 'Development Tools'"  
echo "sudo yum install ncurses-devel openssl-devel"

if [ $missing -eq 0 ]; then
    echo ""
    echo "✓ 环境检查通过，可以开始编译！"
    exit 0
else
    echo ""
    echo "✗ 请先安装缺失的工具"
    exit 1
fi
