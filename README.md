# maliit-keyboard-qt6-builder

为 Droidspaces Plasma Mobile 构建 Qt6 版本的 maliit-keyboard。

## 背景

Ubuntu 26 arm64 仓库中 `maliit-keyboard` 仅有 Qt5 版本，无法在 Wayland 下运行。
`maliit-server-qt6`（Qt6 输入法服务端）因缺少 Qt6 键盘插件而无法加载键盘 UI。

本项目从以下两个未合并的 PR 源码构建 Qt6 版本：

| 组件 | PR | 状态 |
|---|---|---|
| maliit/framework | [PR #125](https://github.com/maliit/framework/pull/125) Qt6 support v2 | Open (branch: `qt6-support_v2`) |
| maliit/keyboard | [PR #235](https://github.com/maliit/keyboard/pull/235) Qt6 support | Open (branch: `qt6-support`) |

## 构建

### GitHub Actions（推荐）

Push 到 `main` 分支自动触发构建，产出 arm64 `.deb` 包。

### 本地构建

```bash
# 需要 arm64 环境（或 QEMU binfmt）
docker buildx build --platform linux/arm64 -f Dockerfile.build -o output .
```

### 产出

```
output/maliit-keyboard-qt6_2.3.1_arm64.deb
```

## 使用方法

### 手动安装（在运行中的容器里）

```bash
# 1. 下载 .deb
wget -O /tmp/maliit-keyboard-qt6.deb \
  "https://github.com/Yizhou147/maliit-keyboard-qt6-builder/releases/latest/download/maliit-keyboard-qt6_2.3.1_arm64.deb"

# 2. 安装
dpkg -i /tmp/maliit-keyboard-qt6.deb || apt-get install -f -y

# 3. 设置环境变量
echo "QT_IM_MODULES=qtvirtualkeyboard" >> /etc/environment

# 4. 配置 kwinrc
sudo -u Gold kwriteconfig6 --file kwinrc --group Wayland --key InputMethod /usr/share/applications/com.github.maliit.keyboard.desktop
sudo -u Gold kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true

# 5. 重启
systemctl restart plasma-mobile
```

### 集成到 Droidspaces Dockerfile

在 `Ubuntu-26-KDE.Dockerfile` 的 mobile 包安装段后添加：

```dockerfile
    # mobile: 安装 Qt6 版 maliit-keyboard（解决屏幕键盘问题）
    if [ "$BUILD_KDE" = "mobile" ]; then \
        wget -q -O /tmp/maliit-keyboard-qt6.deb \
            "https://github.com/Yizhou147/maliit-keyboard-qt6-builder/releases/latest/download/maliit-keyboard-qt6_2.3.1_arm64.deb" && \
        dpkg -i /tmp/maliit-keyboard-qt6.deb || apt-get install -f -y && \
        rm -f /tmp/maliit-keyboard-qt6.deb && \
        echo "QT_IM_MODULES=qtvirtualkeyboard" >> /etc/environment; \
    fi
```

在 `EOF_RUN` 段中，mobile 自启动配置部分添加 kwinrc：

```bash
    # mobile: 配置 KWin 虚拟键盘
    if [ "$BUILD_KDE" = "mobile" ] ; then
    mkdir -p /home/${USERNAME}/.config
    cat <<'EOF' > /home/${USERNAME}/.config/kwinrc
[Wayland]
InputMethod=/usr/share/applications/com.github.maliit.keyboard.desktop
VirtualKeyboardEnabled=true
EOF
    fi
```

## 依赖

构建时需要：
- Qt6 开发包（base, declarative, tools, virtualkeyboard, wayland）
- GLib2, Hunspell, Chewing, Pinyin, Presage
- maliit-framework (Qt6, 从 PR #125 构建)

运行时需要：
- `libqt6virtualkeyboard6`
- `qml6-module-qtquick-virtualkeyboard`
- `qt6-wayland`
- `libmaliit6-plugins2`
- `libhunspell`, `libchewing3`, `libpinyin15`, `libpresage1v5`

## 许可证

maliit-keyboard: LGPL-2.1+ / GPL-3.0+
maliit-framework: LGPL-2.1+ / Apache-2.0
