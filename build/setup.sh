#!/bin/bash
# open mahiro Linux —— 安装完成后的品牌化与兼容层配置（在目标系统 chroot 内运行）
set -x
export DEBIAN_FRONTEND=noninteractive
SRC=/opt/open-mahiro
LOG=/var/log/open-mahiro-setup.log
exec > >(tee -a $LOG) 2>&1

BRAND="open mahiro Linux"
PRETTY="open绪山真寻Linux 13 (Mahiro)"
WALL=/usr/share/backgrounds/open-mahiro

# ---------- 1. 壁纸素材 ----------
mkdir -p "$WALL"
cp -f "$SRC"/branding/*.jpg "$WALL"/ 2>/dev/null
chmod 644 "$WALL"/*.jpg 2>/dev/null

# ---------- 2. 发行版标识 ----------
rm -f /etc/os-release /etc/lsb-release
cat > /etc/os-release <<EOF
PRETTY_NAME="$PRETTY"
NAME="$BRAND"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
ID=debian
ID_LIKE=debian
ANSI_COLOR="1;35"
HOME_URL="https://github.com/yuanshen1834-design"
SUPPORT_URL="https://github.com/yuanshen1834-design"
BUG_REPORT_URL="https://github.com/yuanshen1834-design"
EOF
cat > /etc/lsb-release <<EOF
DISTRIB_ID="$BRAND"
DISTRIB_RELEASE="13"
DISTRIB_CODENAME=trixie
DISTRIB_DESCRIPTION="$PRETTY"
EOF

cat > /etc/issue <<'EOF'
   ____                   __  __       _     _           _
  / __ \ _ __   ___ _ __ |  \/  | __ _| |__ (_)_ __ ___  | |    (_)_ __  _   ___  __
 | |  | | '_ \ / _ \ '_ \| |\/| |/ _` | '_ \| | '__/ _ \ | |    | | '_ \| | | \ \/ /
 | |__| | |_) |  __/ | | | |  | | (_| | | | | | | | (_) || |___ | | | | | |_| |>  <
  \____/| .__/ \___|_| |_|_|  |_|\__,_|_| |_|_|_|  \___/ |_____||_|_| |_|\__,_/_/\_\
        |_|

  open mahiro Linux 13 (Mahiro)  \n \l
EOF
cat > /etc/motd <<EOF

  Welcome to open mahiro Linux 13 (Mahiro)
  Windows apps: double-click any .exe, or use "Install Windows App" in the menu.
  Input method: fcitx5 is enabled, press Ctrl+Space to switch.

EOF

# ---------- 3. GRUB ----------
if [ -f /etc/default/grub ]; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="open mahiro Linux"/' /etc/default/grub || true
    grep -q '^GRUB_DISTRIBUTOR' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="open mahiro Linux"' >> /etc/default/grub
    grep -q '^GRUB_THEME' /etc/default/grub || echo 'GRUB_THEME="/boot/grub/themes/open-mahiro/theme.txt"' >> /etc/default/grub
fi
mkdir -p /boot/grub/themes/open-mahiro
if cp -f "$SRC"/branding/grub-background.png /boot/grub/themes/open-mahiro/background.png 2>/dev/null; then
cat > /boot/grub/themes/open-mahiro/theme.txt <<'EOF'
desktop-image: "background.png"
title-text: "open mahiro Linux"
desktop-color: "#101018"
+ boot_menu {
    left = 20%
    top = 30%
    width = 60%
    height = 52%
    item_color = "#c8c8d8"
    selected_item_color = "#ffffff"
    item_height = 32
    item_padding = 6
    item_spacing = 4
}
+ label {
    top = 90%
    left = 0
    width = 100%
    align = "center"
    color = "#9a9ab0"
    text = "open mahiro Linux 13 (Mahiro)  -  Debian GNU/Linux"
}
EOF
fi

# ---------- 4. 登录界面 ----------
if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
    sed -i "/^\[greeter\]/a background=$WALL/mahiro-02.jpg\nfont-name=Noto Sans CJK SC 11" /etc/lightdm/lightdm-gtk-greeter.conf || true
else
    mkdir -p /etc/lightdm
    cat > /etc/lightdm/lightdm-gtk-greeter.conf <<EOF
[greeter]
background=$WALL/mahiro-02.jpg
font-name=Noto Sans CJK SC 11
EOF
fi

# ---------- 5. 桌面壁纸自动设置（每次登录幂等执行） ----------
cat > /usr/local/bin/open-mahiro-set-wallpaper <<'EOS'
#!/bin/sh
B=/usr/share/backgrounds/open-mahiro/mahiro-02.jpg
command -v xfconf-query >/dev/null 2>&1 || exit 0
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s "$B" 2>/dev/null
done
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'image-style$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s 5 2>/dev/null
done
exit 0
EOS
chmod 755 /usr/local/bin/open-mahiro-set-wallpaper

mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/open-mahiro-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=open mahiro wallpaper
Exec=/usr/local/bin/open-mahiro-set-wallpaper
OnlyShowIn=XFCE;
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# ---------- 6. Wine 兼容层 ----------
dpkg --add-architecture i386 || true
apt-get update || true
apt-get install -y --no-install-recommends \
    wine wine64 wine32:i386 winetricks wine-binfmt cabextract zenity || true

cat > /usr/local/bin/open-mahiro-install-exe <<'EOS'
#!/bin/sh
# 选择 exe 并用 Wine 运行（一点即用）
F=$(zenity --file-selection --title="选择要安装的 Windows 程序 (.exe)" \
    --file-filter="Windows 程序 (*.exe *.msi) | *.exe *.msi" \
    --file-filter="所有文件 | *" 2>/dev/null) || exit 0
[ -z "$F" ] && exit 0
export WINEDEBUG=-all
if ! wineboot -u >/dev/null 2>&1; then
    zenity --error --text="Wine 前缀初始化失败，请检查日志。" 2>/dev/null
    exit 1
fi
( wine "$F" 2>&1 | zenity --text-info --title="安装：$(basename "$F")" --width=700 --height=500 )
zenity --info --text="已尝试运行 $(basename "$F")。\n安装完成后，程序通常出现在开始菜单（Wine 菜单中）。" 2>/dev/null
EOS
chmod 755 /usr/local/bin/open-mahiro-install-exe

cat > /usr/share/applications/open-mahiro-install-exe.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=安装 Windows 软件
Name[zh_CN]=安装 Windows 软件
Comment=选择 .exe 并通过 Wine 安装
Exec=/usr/local/bin/open-mahiro-install-exe
Icon=wine
Terminal=false
Categories=System;Utility;
EOF

# 让 .exe / .msi 默认用 Wine 打开
mkdir -p /usr/share/applications
cat > /usr/share/applications/mimeapps.list <<'EOF'
[Default Applications]
application/x-ms-dos-executable=wine.desktop
application/x-msdownload=wine.desktop
application/x-msi=wine.desktop
EOF

# ---------- 7. 输入法环境 ----------
grep -q 'GTK_IM_MODULE' /etc/environment 2>/dev/null || cat >> /etc/environment <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
mkdir -p /etc/X11/Xsession.d
cat > /etc/X11/Xsession.d/70open-mahiro-ime <<'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF

# ---------- 8. 用户桌面快捷方式 ----------
for H in /home/*; do
    U=$(basename "$H")
    [ -d "$H" ] || continue
    for D in "$H/桌面" "$H/Desktop"; do
        mkdir -p "$D"
        cp -f /usr/share/applications/open-mahiro-install-exe.desktop "$D/" 2>/dev/null
        chown -R "$U":"$U" "$D" 2>/dev/null
    done
    mkdir -p "$H/.config"
    chown -R "$U":"$U" "$H/.config" 2>/dev/null
done

# ---------- 9. 收尾 ----------
update-grub || true
apt-get clean || true
rm -rf /var/lib/apt/lists/* || true

echo "open mahiro Linux setup finished" >> $LOG
exit 0
