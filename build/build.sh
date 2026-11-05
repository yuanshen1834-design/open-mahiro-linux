#!/bin/bash
# 组装 open mahiro Linux ISO
set -e
ISO_OUT=/mnt/g/distro/open-mahiro-linux-13.7.0-amd64-r3.iso
cd /root/iso

echo "== 1. 拷入 overlay =="
rm -rf open-mahiro
cp -r /mnt/g/wsl/overlay/open-mahiro open-mahiro
chmod +x open-mahiro/setup.sh
chmod -R u+w open-mahiro
ls -l open-mahiro open-mahiro/branding

echo "== 2. 启动图 =="
cp -f open-mahiro/branding/isolinux-splash.png isolinux/splash.png
cp -f open-mahiro/branding/isolinux-splash.png splash.png 2>/dev/null || true

echo "== 3. BIOS 菜单 =="
ls isolinux/*.c32
cat > isolinux/isolinux.cfg <<'EOF'
# open mahiro Linux installer (BIOS)
path
prompt 0
timeout 150
default vesamenu.c32

menu title  open mahiro Linux 13.7.0 (Mahiro)

label install
    menu label ^Install open mahiro Linux
    menu default
    kernel /install.amd/vmlinuz
    append vga=788 auto=true priority=critical preseed/file=/cdrom/open-mahiro/preseed.cfg --- quiet
    initrd /install.amd/gtk/initrd.gz

label text
    menu label ^Text mode install
    kernel /install.amd/vmlinuz
    append vga=788 auto=true priority=critical preseed/file=/cdrom/open-mahiro/preseed.cfg --- quiet
    initrd /install.amd/initrd.gz

label manual
    menu label Install ^without preseed (fully manual)
    kernel /install.amd/vmlinuz
    append vga=788 --- quiet
    initrd /install.amd/gtk/initrd.gz

label rescue
    menu label ^Rescue mode
    kernel /install.amd/vmlinuz
    append vga=788 rescue/enable=true --- quiet
    initrd /install.amd/initrd.gz
EOF

echo "== 4. GRUB 菜单（UEFI） =="
cp -f boot/grub/grub.cfg boot/grub/grub.cfg.orig
{
cat <<'EOF'
set default=0
menuentry 'Install open mahiro Linux' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 auto=true priority=critical preseed/file=/cdrom/open-mahiro/preseed.cfg --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry 'Text mode install' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 auto=true priority=critical preseed/file=/cdrom/open-mahiro/preseed.cfg --- quiet
    initrd   /install.amd/initrd.gz
}
menuentry 'Install without preseed (fully manual)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry 'Rescue mode' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 rescue/enable=true --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
EOF
cat boot/grub/grub.cfg.orig
cat <<'EOF'
set default=0
EOF
} > boot/grub/grub.cfg
rm -f boot/grub/grub.cfg.orig

echo "== 5. 光盘标识 =="
mkdir -p .disk
cat > .disk/info <<'EOF'
open绪山真寻Linux 13.7.0 (Mahiro) - amd64 - custom build
EOF
cat > README.txt <<'EOF'
open绪山真寻Linux 13.7.0 (Mahiro)  —  open mahiro Linux
========================================================

基于 Debian GNU/Linux 13 (trixie) 的定制发行版：
  · XFCE 桌面，默认中文环境（zh_CN.UTF-8）
  · fcitx5 中文输入法、Noto CJK / 文泉驿字体
  · LibreOffice、Firefox、VLC、GIMP 等常用软件
  · Wine 兼容层：双击 .exe 即可安装 Windows 程序

安装：从 U 盘或虚拟机启动，选择第一项「自动安装」，
      默认账户 mahiro / 密码 mahiro（安装后可自行修改）。

默认软件源：清华 TUNA 镜像（安装过程中需联网下载软件包）。
EOF

echo "== 6. 重算 md5sum =="
rm -f md5sum.txt
find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
wc -l md5sum.txt

echo "== 7. 打包 ISO =="
rm -f "$ISO_OUT"
xorriso -as mkisofs -r -V "OPEN_MAHIRO_LINUX" -o "$ISO_OUT" \
  -J -joliet-long -cache-inodes \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -isohybrid-gpt-basdat \
  . 2>&1 | tail -5

ls -lh "$ISO_OUT"
