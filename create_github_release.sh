#!/bin/bash

# GitHub Release 创建脚本
# 需要设置 GITHUB_TOKEN 环境变量

set -e

REPO="DustReliant/luci-app-filetransfer"
TAG="v1.2.0"
RELEASE_NAME="LuCI App File Transfer v1.2.0 - 重大功能更新"
RELEASE_BODY=$(cat releases/v1.2.0/GITHUB_RELEASE_NOTES.md)

echo "创建 GitHub Release..."

# 检查是否设置了 GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
    echo "错误：请设置 GITHUB_TOKEN 环境变量"
    echo "获取方法：https://github.com/settings/tokens"
    exit 1
fi

# 创建 Release
RELEASE_ID=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO/releases \
  -d "{
    \"tag_name\": \"$TAG\",
    \"target_commitish\": \"master\",
    \"name\": \"$RELEASE_NAME\",
    \"body\": $(echo "$RELEASE_BODY" | jq -R -s .),
    \"draft\": false,
    \"prerelease\": false
  }" | jq -r .id)

if [ "$RELEASE_ID" = "null" ]; then
    echo "错误：创建 Release 失败"
    exit 1
fi

echo "Release 创建成功，ID: $RELEASE_ID"

# 上传 IPK 文件
echo "上传 IPK 文件..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @releases/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=luci-app-filetransfer_1.2.0_all.ipk"

# 上传校验和文件
echo "上传校验和文件..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary @releases/v1.2.0/luci-app-filetransfer_1.2.0_all.ipk.sha256 \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=luci-app-filetransfer_1.2.0_all.ipk.sha256"

echo "✅ GitHub Release 创建完成！"
echo "🌐 访问地址：https://github.com/$REPO/releases/tag/$TAG" 