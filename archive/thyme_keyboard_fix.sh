#!/bin/bash
# Emergency fix for Thyme OS keyboard/mouse issues
# This script updates GRUB to add boot options that force USB/HID loading

GRUB_FILES_DIR="/home/meister/mintbook/grub_files"
TARGET_DEVICE="${1:-/dev/sdb}"

echo "🛠️ Thyme OS Keyboard/Mouse Emergency Fix"
echo "========================================"
echo "Target device: $TARGET_DEVICE"
echo

# Mount the EFI partition
EFI_PARTITION="${TARGET_DEVICE}1"
if [[ "$TARGET_DEVICE" =~ nvme ]]; then
    EFI_PARTITION="${TARGET_DEVICE}p1"
fi

TEMP_MOUNT="/tmp/thyme_efi_fix"
mkdir -p "$TEMP_MOUNT"

echo "Mounting EFI partition..."
sudo mount "$EFI_PARTITION" "$TEMP_MOUNT"

# Create updated GRUB config with USB/HID fixes
echo "Creating updated GRUB configuration with USB/HID fixes..."

ROOT_PARTITION="${TARGET_DEVICE}3"
if [[ "$TARGET_DEVICE" =~ nvme ]]; then
    ROOT_PARTITION="${TARGET_DEVICE}p3"
fi

ROOT_UUID=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")

sudo tee "$TEMP_MOUNT/EFI/thyme/grub.cfg" > /dev/null << EOF
# Thyme OS GRUB Configuration - USB/HID Fixed
set timeout=15
set default=0

echo "🍃 Thyme OS Loading - USB/HID Emergency Fix..."

insmod part_gpt
insmod fat
insmod ext2
insmod font
insmod gfxterm
insmod usb_keyboard
insmod ohci
insmod uhci
insmod ehci

menuentry "🛠️ Thyme OS - USB/HID Emergency Fix" {
    echo "Booting with USB/HID emergency parameters..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro quiet splash irqpoll usbcore.autosuspend=-1 usbhid.mousepoll=0 usbhid.quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop modprobe.blacklist=
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Force All USB Modules" {
    echo "Loading all USB and input modules..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 psmouse.proto=imps psmouse.rate=100 i8042.reset i8042.nomux i8042.nopnp i8042.noloop i8042.direct i8042.dumbkbd
    initrd /boot/initrd.img
}

menuentry "🔧 Thyme OS - Debug Mode (verbose)" {
    echo "Booting with maximum debugging for input devices..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro debug loglevel=8 usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.debug i8042.reset i8042.nomux i8042.nopnp i8042.noloop
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell (bypass login)" {
    echo "Booting to emergency shell..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro single init=/bin/bash usbcore.autosuspend=-1 i8042.reset
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Original Boot" {
    echo "Original boot parameters..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro quiet splash
    initrd /boot/initrd.img
}

menuentry "🔄 Reboot" {
    reboot
}

menuentry "⚡ Shutdown" {
    halt
}
EOF

# Copy to standard boot location
sudo cp "$TEMP_MOUNT/EFI/thyme/grub.cfg" "$TEMP_MOUNT/EFI/BOOT/grub.cfg"

echo "✅ Updated GRUB configuration with USB/HID fixes"

# Unmount
sudo umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"

echo
echo "🍃 Fix Applied Successfully!"
echo "==========================================="
echo "Reboot your MacBook and select:"
echo "   '🛠️ Thyme OS - USB/HID Emergency Fix'"
echo
echo "This boot option includes:"
echo "• Forced USB module loading"
echo "• Apple USB device quirks"
echo "• i8042 keyboard controller fixes"
echo "• Disabled USB autosuspend"
echo
echo "If that doesn't work, try:"
echo "   '🔧 Thyme OS - Debug Mode' for troubleshooting"
echo "   '🚑 Emergency Shell' to bypass login completely"