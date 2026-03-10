#!/bin/bash

# 加载 .env 环境变量（包含 DEVELOPER_ID_CERT）
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$DEVELOPER_ID_CERT" ]; then
    echo "错误：未设置 DEVELOPER_ID_CERT 环境变量，请在 .env 文件中配置。"
    exit 1
fi

# 创建输出目录
mkdir -p build

echo "开始编译 Mac 原生语音输入法..."

# 编译 Swift 源码
# 注意：这只是一个基础的命令行编译，实际发布需要使用 Xcode 项目文件进行签名和权限配置
swiftc \
    src-native/main.swift \
    src-native/VoiceInputApp.swift \
    src-native/Managers/AudioRecorder.swift \
    src-native/Managers/KeyboardManager.swift \
    src-native/Managers/HotKeyManager.swift \
    src-native/Managers/AccessibilityManager.swift \
    src-native/Managers/MicrophoneManager.swift \
    src-native/Network/ASRConfig.swift \
    src-native/Network/VolcanoASRClient.swift \
    src-native/UI/InputWindowController.swift \
    src-native/UI/SimpleInputWindowController.swift \
    src-native/UI/Preferences/PreferencesWindowController.swift \
    src-native/UI/Preferences/GeneralViewController.swift \
    src-native/UI/Preferences/APIConfigViewController.swift \
    src-native/UI/KeyRecorderView.swift \
    src-native/UI/PermissionSetupWindowController.swift \
    src-native/Utils/AppActivation.swift \
    -o build/VoiceInputApp \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -target arm64-apple-macosx12.0 \
    -framework Cocoa \
    -framework AVFoundation \
    -framework CoreGraphics

if [ $? -eq 0 ]; then
    echo "编译成功！开始构建 .app 包..."
    
    APP_NAME="语音输入法.app"
    rm -rf "build/$APP_NAME"
    mkdir -p "build/$APP_NAME/Contents/MacOS"
    mkdir -p "build/$APP_NAME/Contents/Resources"
    
    # 移动二进制文件
    mv build/VoiceInputApp "build/$APP_NAME/Contents/MacOS/VoiceInputApp"
    
    # 复制 Info.plist
    cp src-native/Info.plist "build/$APP_NAME/Contents/Info.plist"
    
    # 复制配置文件到 Resources 目录
    cp asr_settings.json "build/$APP_NAME/Contents/Resources/asr_settings.json"
    
    # 复制应用图标
    cp src-native/assets/AppIcon.icns "build/$APP_NAME/Contents/Resources/AppIcon.icns"
    
    # 修复"已损坏"提示：使用 Developer ID 证书签名
    echo "正在使用开发者证书签名应用..."
    codesign --force --deep --sign "$DEVELOPER_ID_CERT" "build/$APP_NAME"
    
    # 清除隔离属性
    echo "正在清除隔离属性..."
    xattr -cr "build/$APP_NAME"
    
    echo "打包完成：build/$APP_NAME"
    echo "您可以直接在 Finder 中打开 build 文件夹运行它。"
else
    echo "编译失败。"
fi
