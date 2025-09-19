#!/bin/bash
# Thyme OS EFI Cleanup and Fix Script
# Fixes boot issues caused by changing drive letters and multiple installations

set -e

echo "🛠️ Thyme OS EFI Cleanup and Fix"
echo "==============================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[FIX]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Find Thyme OS installation automatically
find_thyme_installation() {
    log "Searching for Thyme OS installation..."
    
    # Look for partitions labeled ThymeOS
    THYME_ROOT_DEVICE=$(blkid | grep 'LABEL="ThymeOS"' | cut -d: -f1)
    THYME_EFI_DEVICE=$(blkid | grep 'LABEL="THYME_EFI"' | cut -d: -f1)
    
    if [[ -z "$THYME_ROOT_DEVICE" ]] || [[ -z "$THYME_EFI_DEVICE" ]]; then
        error "Could not find Thyme OS installation"
        echo "Looking for any EFI and ext4 partitions..."
        blkid | grep -E "(THYME|ThymeOS)"
        exit 1
    fi
    
    log "Found Thyme OS installation:"
    log "  EFI Partition: $THYME_EFI_DEVICE"
    log "  Root Partition: $THYME_ROOT_DEVICE"
    
    export THYME_EFI_DEVICE THYME_ROOT_DEVICE
}

# Clean and rebuild EFI partition
clean_efi_partition() {
    log "Cleaning and rebuilding EFI partition..."
    
    # Create mount point
    TEMP_EFI_MOUNT="/tmp/thyme_efi_cleanup"
    mkdir -p "$TEMP_EFI_MOUNT"
    
    # Mount EFI partition
    sudo mount "$THYME_EFI_DEVICE" "$TEMP_EFI_MOUNT"
    
    log "Current EFI contents:"
    ls -la "$TEMP_EFI_MOUNT" 2>/dev/null || echo "EFI partition is empty or corrupted"
    
    # Completely clean EFI partition
    warn "Cleaning ALL EFI entries (this will remove any conflicting bootloaders)"
    sudo rm -rf "$TEMP_EFI_MOUNT"/* 2>/dev/null || true
    
    # Create clean EFI structure
    sudo mkdir -p "$TEMP_EFI_MOUNT/EFI/BOOT"
    sudo mkdir -p "$TEMP_EFI_MOUNT/EFI/thyme"
    
    log "✅ EFI partition cleaned"
    
    export TEMP_EFI_MOUNT
}

# Install clean GRUB bootloader
install_clean_grub() {
    log "Installing clean GRUB bootloader..."
    
    local grub_files_dir="/home/meister/mintbook/grub_files"
    
    # Check for GRUB files
    if [[ ! -f "$grub_files_dir/grubia32.efi" ]]; then
        error "GRUB 32-bit EFI file not found: $grub_files_dir/grubia32.efi"
        exit 1
    fi
    
    # Install 32-bit GRUB for MacBook compatibility
    sudo cp "$grub_files_dir/grubia32.efi" "$TEMP_EFI_MOUNT/EFI/BOOT/bootia32.efi"
    sudo cp "$grub_files_dir/grubia32.efi" "$TEMP_EFI_MOUNT/EFI/thyme/grubia32.efi"
    
    # Also install 64-bit if available (fallback)
    if [[ -f "$grub_files_dir/grubx64.efi" ]]; then
        sudo cp "$grub_files_dir/grubx64.efi" "$TEMP_EFI_MOUNT/EFI/BOOT/bootx64.efi"
        sudo cp "$grub_files_dir/grubx64.efi" "$TEMP_EFI_MOUNT/EFI/thyme/grubx64.efi"
        log "Both 32-bit and 64-bit GRUB installed"
    else
        log "32-bit GRUB installed (MacBook2,1 compatible)"
    fi
}

# Create device-agnostic GRUB configuration
create_device_agnostic_grub() {
    log "Creating device-agnostic GRUB configuration..."
    
    # Get UUID instead of device name (UUIDs don't change)
    ROOT_UUID=$(sudo blkid -s UUID -o value "$THYME_ROOT_DEVICE")
    
    if [[ -z "$ROOT_UUID" ]]; then
        error "Could not get UUID for root partition"
        exit 1
    fi
    
    log "Root UUID: $ROOT_UUID"
    
    # Create GRUB config using UUID (device-independent)
    sudo tee "$TEMP_EFI_MOUNT/EFI/thyme/grub.cfg" > /dev/null << EOF
# Thyme OS GRUB Configuration - Device Independent
# Uses UUIDs instead of device names to handle changing drive letters
set timeout=15
set default=0

echo "🍃 Thyme OS Loading (UUID-based, USB/HID Fixed)..."

insmod part_gpt
insmod fat
insmod ext2
insmod font
insmod gfxterm
insmod usb_keyboard
insmod ohci
insmod uhci
insmod ehci
insmod search_fs_uuid

menuentry "🍃 Thyme OS - Default (USB/HID Fixed)" {
    echo "Booting Thyme OS with USB/HID fixes..."
    echo "Root UUID: $ROOT_UUID"
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 usbhid.quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop
    initrd /boot/initrd.img
}

menuentry "🛠️ Thyme OS - Force All USB Modules" {
    echo "Loading all USB modules for maximum compatibility..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 psmouse.proto=imps psmouse.rate=100 i8042.reset i8042.nomux i8042.nopnp i8042.noloop i8042.direct i8042.dumbkbd
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Safe Mode" {
    echo "Safe mode with input fixes..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro nomodeset acpi=off usbcore.autosuspend=-1 i8042.reset quiet
    initrd /boot/initrd.img
}

menuentry "🔧 Debug Mode (verbose USB/HID)" {
    echo "Debug mode with verbose USB/HID logging..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro debug loglevel=8 usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.debug i8042.reset i8042.nomux
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell (bypass login)" {
    echo "Emergency shell access..."
    search --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=UUID=$ROOT_UUID ro single init=/bin/bash usbcore.autosuspend=-1 i8042.reset
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
    sudo cp "$TEMP_EFI_MOUNT/EFI/thyme/grub.cfg" "$TEMP_EFI_MOUNT/EFI/BOOT/grub.cfg"
    
    log "✅ Device-agnostic GRUB configuration created"
}

# Clean up and finish
cleanup_and_finish() {
    log "Cleaning up..."
    
    # Sync all changes
    sync
    
    # Unmount EFI partition
    sudo umount "$TEMP_EFI_MOUNT"
    rmdir "$TEMP_EFI_MOUNT"
    
    log "✅ Cleanup completed"
}

# Show final instructions
show_instructions() {
    echo
    echo -e "${GREEN}🎉 Thyme OS EFI Fix Completed!${NC}"
    echo "==============================="
    echo
    echo "What was fixed:"
    echo "• EFI partition completely cleaned"
    echo "• GRUB bootloader reinstalled"
    echo "• Configuration now uses UUIDs (device-independent)"
    echo "• USB/HID fixes included in all boot options"
    echo "• Multiple boot options for troubleshooting"
    echo
    echo "Next steps:"
    echo "1. Safely eject the SSD from this system"
    echo "2. Connect to MacBook2,1"
    echo "3. Hold Alt/Option during boot"
    echo "4. Select 'Thyme OS' or 'EFI Boot'"
    echo "5. Choose '🍃 Thyme OS - Default (USB/HID Fixed)'"
    echo
    echo "If keyboard/mouse still don't work:"
    echo "• Try '🛠️ Force All USB Modules' option"
    echo "• Try '🚑 Emergency Shell' to bypass login"
    echo
    echo "The UUID-based configuration should work regardless"
    echo "of which drive letter (sdb/sdc/sdd) the system assigns!"
}

# Main execution
main() {
    find_thyme_installation
    clean_efi_partition
    install_clean_grub
    create_device_agnostic_grub
    cleanup_and_finish
    show_instructions
}

# Run the fix
main "$@"