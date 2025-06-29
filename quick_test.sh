#!/bin/bash

# 快速测试脚本
ROUTER_IP="${1:-192.168.31.1}"

echo "======================================"
echo "快速系统检查"
echo "路由器: $ROUTER_IP"
echo "======================================"
echo ""

# 测试主要URL
echo "测试URL访问状态："
echo "-------------------"

urls=(
    "http://$ROUTER_IP"
    "http://$ROUTER_IP/cgi-bin/luci"
    "http://$ROUTER_IP/cgi-bin/luci/admin"
    "http://$ROUTER_IP/cgi-bin/luci/admin/system"
    "http://$ROUTER_IP/cgi-bin/luci/admin/system/filetransfer"
)

for url in "${urls[@]}"; do
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    case $http_code in
        200) status="✓ OK (200)" ;;
        301|302) status="✓ 重定向 ($http_code)" ;;
        403) status="⚠ 需要认证 (403)" ;;
        404) status="✗ 未找到 (404)" ;;
        500) status="✗ 服务器错误 (500)" ;;
        000) status="✗ 无法连接" ;;
        *) status="? 状态码: $http_code" ;;
    esac
    printf "%-60s %s\n" "$url" "$status"
done

echo ""
echo "在路由器上检查服务状态..."
echo "-------------------"

ssh root@$ROUTER_IP << 'EOF'
    echo "Web服务器进程："
    if pgrep nginx > /dev/null; then
        echo "✓ nginx 正在运行"
    elif pgrep uhttpd > /dev/null; then
        echo "✓ uhttpd 正在运行"
    else
        echo "✗ 没有找到Web服务器进程"
    fi
    
    if pgrep uwsgi > /dev/null; then
        echo "✓ uWSGI 正在运行"
    fi
    
    echo ""
    echo "文件传输应用状态："
    if [ -f /usr/lib/lua/luci/controller/filetransfer.lua ]; then
        echo "✓ 控制器文件存在"
    else
        echo "✗ 控制器文件不存在"
    fi
    
    if [ -d /tmp/upload ]; then
        echo "✓ 上传目录存在"
        ls -ld /tmp/upload
    else
        echo "✗ 上传目录不存在"
    fi
    
    if [ -f /tmp/filetransfer.log ]; then
        echo "✓ 日志文件存在"
        echo "  最后3条日志："
        tail -n 3 /tmp/filetransfer.log | sed 's/^/    /'
    else
        echo "⚠ 日志文件不存在"
    fi
EOF

echo ""
echo "======================================"
echo "检查完成"
echo "======================================" 