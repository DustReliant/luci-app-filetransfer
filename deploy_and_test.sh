#!/bin/bash

# 文件传输应用部署和测试脚本
# 使用方法: ./deploy_and_test.sh [router_ip]

ROUTER_IP="${1:-192.168.31.1}"
OPENWRT_DIR="/home/lijz/Build_OpenWRT/openwrt"
PACKAGE_NAME="luci-app-filetransfer"

echo "======================================"
echo "文件传输应用部署脚本"
echo "======================================"
echo "目标路由器: $ROUTER_IP"
echo ""

# 步骤1: 编译包
echo "[1/5] 开始编译包..."
cd "$OPENWRT_DIR"
make package/$PACKAGE_NAME/clean
if make package/$PACKAGE_NAME/compile V=s; then
    echo "✓ 编译成功"
else
    echo "✗ 编译失败"
    exit 1
fi

# 步骤2: 查找编译好的包
echo ""
echo "[2/5] 查找编译好的包..."
IPK_FILE=$(find bin/packages -name "${PACKAGE_NAME}*.ipk" -type f | head -n 1)
if [ -z "$IPK_FILE" ]; then
    echo "✗ 找不到编译好的IPK文件"
    exit 1
fi
echo "✓ 找到IPK文件: $IPK_FILE"

# 步骤3: 复制到路由器
echo ""
echo "[3/5] 复制IPK到路由器..."
if scp "$IPK_FILE" root@$ROUTER_IP:/tmp/; then
    echo "✓ 复制成功"
else
    echo "✗ 复制失败"
    exit 1
fi

# 步骤4: 在路由器上安装
echo ""
echo "[4/5] 在路由器上安装包..."
ssh root@$ROUTER_IP << 'EOF'
    echo "移除旧版本..."
    opkg remove luci-app-filetransfer
    
    echo "安装新版本..."
    opkg install /tmp/luci-app-filetransfer*.ipk
    
    echo "重启Web服务..."
    if [ -f /etc/init.d/nginx ]; then
        /etc/init.d/nginx restart
    elif [ -f /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd restart
    fi
    
    echo "清理LuCI缓存..."
    rm -rf /tmp/luci-*
    
    echo "创建上传目录..."
    mkdir -p /tmp/upload
    chmod 755 /tmp/upload
    
    echo "创建日志文件..."
    touch /tmp/filetransfer.log
    chmod 666 /tmp/filetransfer.log
EOF

# 步骤5: 测试访问
echo ""
echo "[5/5] 测试系统访问..."
echo ""

# 测试主页
echo -n "测试OpenWRT主页 (http://$ROUTER_IP)... "
if curl -s -o /dev/null -w "%{http_code}" "http://$ROUTER_IP" | grep -q "200\|301\|302"; then
    echo "✓ 可以访问"
else
    echo "✗ 无法访问"
fi

# 测试LuCI登录页
echo -n "测试LuCI登录页 (http://$ROUTER_IP/cgi-bin/luci)... "
if curl -s -o /dev/null -w "%{http_code}" "http://$ROUTER_IP/cgi-bin/luci" | grep -q "200\|301\|302\|403"; then
    echo "✓ 可以访问"
else
    echo "✗ 无法访问"
fi

# 测试文件传输应用
echo -n "测试文件传输应用... "
if curl -s -o /dev/null -w "%{http_code}" "http://$ROUTER_IP/cgi-bin/luci/admin/system/filetransfer" | grep -q "200\|301\|302\|403"; then
    echo "✓ 应用已安装"
else
    echo "✗ 应用未找到"
fi

echo ""
echo "======================================"
echo "部署完成！"
echo "======================================"
echo ""
echo "请访问以下地址进行测试："
echo "1. OpenWRT主页: http://$ROUTER_IP"
echo "2. LuCI管理界面: http://$ROUTER_IP/cgi-bin/luci"
echo "3. 文件传输应用: http://$ROUTER_IP/cgi-bin/luci/admin/system/filetransfer"
echo ""
echo "如需查看日志："
echo "ssh root@$ROUTER_IP 'tail -f /tmp/filetransfer.log'"
echo "" 