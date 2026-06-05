#!/bin/bash
# ESPHome 版本备份脚本
# 用法: ./scripts/backup-version.sh <project-name> <version-label>
# 示例: ./scripts/backup-version.sh epaper-weather-display "添加日志调试"

set -e

PROJECT="$1"
VERSION_LABEL="$2"
BASE_DIR="/Users/c1pher/.openclaw/workspace/esphome/projects"
PROJECT_DIR="$BASE_DIR/$PROJECT"

if [ -z "$PROJECT" ] || [ -z "$VERSION_LABEL" ]; then
    echo "用法: $0 <project-name> <version-label>"
    echo "示例: $0 epaper-weather-display \"添加日志调试\""
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ 项目不存在: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

# 找到当前最新版本号
CURRENT_LINK="current.yaml"
CURRENT_TARGET=$(readlink $CURRENT_LINK)
CURRENT_VERSION=$(basename $CURRENT_TARGET .yaml)  # e.g. v1
V_NUM=${CURRENT_VERSION#v}  # e.g. 1
NEW_V_NUM=$((V_NUM + 1))
NEW_VERSION="v${NEW_V_NUM}.yaml"

# 备份：复制当前版本到新版本（CURRENT_VERSION 已经是 v{N} 格式）
cp versions/${CURRENT_VERSION}.yaml versions/$NEW_VERSION
echo "✅ 备份 $CURRENT_VERSION → $NEW_VERSION"

# 更新软链接
rm -f $CURRENT_LINK
ln -s versions/$NEW_VERSION $CURRENT_LINK
echo "🔗 current.yaml → $NEW_VERSION"

# 记录 changelog
DATE=$(date "+%Y-%m-%d %H:%M")
echo "" >> CHANGELOG.md
echo "## $NEW_VERSION ($DATE)" >> CHANGELOG.md
echo "" >> CHANGELOG.md
echo "- **$VERSION_LABEL**" >> CHANGELOG.md
echo "  - 备份自 $CURRENT_VERSION" >> CHANGELOG.md

echo "📝 CHANGELOG.md 已更新"
echo "🎯 下一步：编辑 versions/$NEW_VERSION"