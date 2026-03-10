#!/bin/bash

# ============================================
# DMG 安装包打包脚本
# ============================================
# 用法：./create-dmg.sh
# 前提：需要先运行 ./build-native.sh 编译应用
# ============================================

set -e

APP_NAME="语音输入法"
APP_PATH="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="build/${DMG_NAME}"
DMG_TEMP="build/dmg_temp"
VOLUME_NAME="${APP_NAME}"

# 检查 .app 是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 错误：找不到 $APP_PATH"
    echo "请先运行 ./build-native.sh 编译应用"
    exit 1
fi

echo "🚀 开始创建 DMG 安装包..."

# 清理旧文件
rm -rf "$DMG_TEMP"
rm -f "$DMG_PATH"

# 创建临时目录结构
mkdir -p "$DMG_TEMP"

# 复制 .app 到临时目录
cp -R "$APP_PATH" "$DMG_TEMP/"

# 复制配置模板文件（用户需要这些来配置 API）
cp api_keys.env.example "$DMG_TEMP/"
cp asr_settings.json "$DMG_TEMP/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_TEMP/Applications"

# 创建简易说明文件
cat > "$DMG_TEMP/使用说明.txt" << 'EOF'
Mac 语音输入法 - 快速开始
==========================

【安装步骤】
1. 拖动「语音输入法.app」到「Applications」文件夹
2. 首次打开，在菜单栏点击应用图标 → 「设置」
3. 在设置页面填入你的 App ID 和 Access Token
4. 按照提示授予麦克风和辅助功能权限
5. 开始语音输入！

【快捷键说明（两种模式同时可用）】
• 按住说话：fn + Control（按住说话，松开自动粘贴）
• 按下说话：Ctrl + Option + Cmd + 6（按下开始，回车确认）
• 取消录音：ESC

快捷键可在设置页面自定义。

【获取 API 密钥】
1. 注册火山引擎账号：https://www.volcengine.com
2. 进入语音技术控制台：https://console.volcengine.com/speech/app
3. 创建应用，获取 App ID 和 Access Token

💡 火山引擎提供免费额度，个人日常使用完全够用

【高级配置】
编辑 asr_settings.json 可调整识别参数（如断句灵敏度、语义顺滑等）

详细文档：请查看 GitHub 仓库的 README

EOF

echo "📦 正在创建 DMG..."

# 创建 DMG（使用 hdiutil）
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# 清理临时目录
rm -rf "$DMG_TEMP"

# 获取文件大小
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "✅ DMG 打包完成！"
echo "📍 位置：$DMG_PATH"
echo "📏 大小：$DMG_SIZE"
echo ""
echo "你可以将此文件上传到 GitHub Release"
