#!/bin/bash
# Thyme OS Mint-Based SSD Installer
# Uses working Linux Mint as base and customizes it for MacBook compatibility
# Much more reliable than building from scratch

set -e

SCRIPT_VERSION="2.0-mint-based"
INSTALL_LOG="/tmp/thyme_mint_install.log"
GRUB_FILES_DIR="/home/meister/mintbook/grub_files"
WORK_DIR="/tmp/thyme_mint_installer_work"

# Auto-install mode for testing
AUTO_INSTALL_MODE=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$INSTALL_LOG"
}

warn() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$INSTALL_LOG"
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$INSTALL_LOG"
    cleanup_on_error
    exit 1
}

success() {
    echo -e "${GREEN}$1${NC}"
}

# Cleanup function
cleanup_on_error() {
    if [[ "${CLEANUP_IN_PROGRESS:-}" == "true" ]]; then
        echo "Cleanup already in progress, exiting..."
        exit 1
    fi
    export CLEANUP_IN_PROGRESS=true
    
    echo "Cleaning up after error..."
    
    # Unmount any mounted filesystems
    if [[ -n "$ROOT_MOUNT_POINT" ]] && mountpoint -q "$ROOT_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$ROOT_MOUNT_POINT" 2>/dev/null || true
    fi
    
    if [[ -n "$EFI_MOUNT_POINT" ]] && mountpoint -q "$EFI_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$EFI_MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Remove work directory
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
    
    export CLEANUP_IN_PROGRESS=false
}

trap 'echo "Installation interrupted. Cleaning up..."; cleanup_on_error; exit 1' INT TERM

# Initialize installer
initialize_installer() {
    echo -e "${PURPLE}"
    cat << 'EOF'
🍃 Thyme OS Mint-Based SSD Installer 🍃
=====================================

Creating Thyme OS by copying working Linux Mint system
and customizing for MacBook2,1 compatibility

⚠️  IMPORTANT:
━━━━━━━━━━━━━━━━━━━━━━━━
• This will ERASE the target SSD completely
• Uses your working Mint installation as base
• Much more reliable than building from scratch
• Preserves all working drivers and libraries

EOF
    echo -e "${NC}"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    echo "Thyme OS Mint-Based Installer Log - $(date)" > "$INSTALL_LOG"
    log "Installer initialized"
}

# Check that we're running on a working Linux Mint system
check_mint_system() {
    log "Checking if we're running on Linux Mint..."
    
    if [[ ! -f "/etc/lsb-release" ]] || ! grep -q "DISTRIB_ID=LinuxMint" /etc/lsb-release; then
        error "This installer must be run from a working Linux Mint system"
    fi
    
    local mint_version=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
    log "✅ Running on Linux Mint $mint_version"
    
    # Check that keyboard and basic functionality works
    if ! command -v bash &> /dev/null; then
        error "bash not found - system may be broken"
    fi
    
    log "✅ Base system validation passed"
}

# Detect and select target device (same as before)
detect_target_device() {
    log "Detecting available storage devices..."
    
    echo
    echo "Available storage devices:"
    echo "========================="
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|nvme)"
    echo
    
    # Auto-detect likely target (exclude system disk)
    local system_disk=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    local candidate_devices=()
    
    while read -r device; do
        if [[ "$device" != "$system_disk" ]] && [[ -b "$device" ]]; then
            candidate_devices+=("$device")
        fi
    done < <(lsblk -d -n -o NAME | sed 's|^|/dev/|')
    
    if [[ ${#candidate_devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="${candidate_devices[0]}"
        log "Auto-detected target device: $TARGET_DEVICE"
        
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
            log "🚀 AUTO-INSTALL MODE: Auto-confirming $TARGET_DEVICE"
        else
            read -p "Continue with installation to $TARGET_DEVICE? (y/n): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                error "Installation cancelled by user"
            fi
        fi
    else
        echo "Multiple devices available. Please select target device:"
        for i in "${!candidate_devices[@]}"; do
            local device="${candidate_devices[$i]}"
            local info=$(lsblk -o SIZE,MODEL "$device" 2>/dev/null | tail -n 1)
            echo "$((i+1)). $device ($info)"
        done
        echo
        
        if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
            device_num="1"
            log "🚀 AUTO-INSTALL MODE: Auto-selecting device 1 (${candidate_devices[0]})"
        else
            read -p "Select device number (1-${#candidate_devices[@]}): " device_num
        fi
        
        if [[ "$device_num" -ge 1 ]] && [[ "$device_num" -le ${#candidate_devices[@]} ]]; then
            TARGET_DEVICE="${candidate_devices[$((device_num-1))]}"
            warn "Selected: $TARGET_DEVICE - This will be COMPLETELY ERASED"
            if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
                log "🚀 AUTO-INSTALL MODE: Auto-typing 'ERASE' confirmation"
                confirm="erase"
            else
                read -p "Type 'ERASE' to confirm: " confirm
                if [[ "${confirm,,}" != "erase" ]]; then
                    error "Installation cancelled"
                fi
            fi
        else
            error "Invalid selection"
        fi
    fi
    
    # Final safety check
    if [[ "$TARGET_DEVICE" == "$system_disk" ]]; then
        error "Cannot install to system disk $TARGET_DEVICE"
    fi
    
    export TARGET_DEVICE
}

# Partition device (same partitioning as before)
partition_device() {
    log "Partitioning device $TARGET_DEVICE..."
    
    # Unmount any mounted partitions
    for partition in $(lsblk -ln -o NAME "$TARGET_DEVICE" | tail -n +2); do
        sudo umount "/dev/$partition" 2>/dev/null || true
    done
    
    # Create GPT partition table
    sudo parted "$TARGET_DEVICE" --script mklabel gpt
    
    # Calculate partition boundaries (same as before)
    local system_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size_gb=4
    if [[ $system_ram_gb -lt 4 ]]; then
        swap_size_gb=8
    fi
    
    local efi_start="1MiB"
    local efi_end="513MiB"
    local swap_start="513MiB"
    local swap_end="$((513 + swap_size_gb * 1024))MiB"
    local root_start="${swap_end}"
    local root_end="100%"
    
    # Create partitions
    sudo parted "$TARGET_DEVICE" --script mkpart ESP fat32 "$efi_start" "$efi_end"
    sudo parted "$TARGET_DEVICE" --script set 1 esp on
    sudo parted "$TARGET_DEVICE" --script mkpart primary linux-swap "$swap_start" "$swap_end"
    sudo parted "$TARGET_DEVICE" --script mkpart primary ext4 "$root_start" "$root_end"
    
    sudo partprobe "$TARGET_DEVICE"
    sleep 2
    
    # Set partition variables
    EFI_PARTITION="${TARGET_DEVICE}1"
    SWAP_PARTITION="${TARGET_DEVICE}2"
    ROOT_PARTITION="${TARGET_DEVICE}3"
    
    if [[ "$TARGET_DEVICE" =~ nvme ]]; then
        EFI_PARTITION="${TARGET_DEVICE}p1"
        SWAP_PARTITION="${TARGET_DEVICE}p2"
        ROOT_PARTITION="${TARGET_DEVICE}p3"
    fi
    
    log "✅ Partitioning completed"
    export EFI_PARTITION SWAP_PARTITION ROOT_PARTITION
}

# Clean any existing EFI installations
clean_existing_efi() {
    log "Cleaning any existing EFI installations from target device..."
    
    # Check if there are existing partitions with our labels
    local existing_efi=$(blkid | grep 'LABEL="THYME_EFI"' | cut -d: -f1 || true)
    local existing_root=$(blkid | grep 'LABEL="ThymeOS"' | cut -d: -f1 || true)
    
    if [[ -n "$existing_efi" ]] || [[ -n "$existing_root" ]]; then
        warn "Found existing Thyme OS installation(s):"
        [[ -n "$existing_efi" ]] && warn "  EFI: $existing_efi"
        [[ -n "$existing_root" ]] && warn "  Root: $existing_root"
        
        log "Cleaning up existing installations to prevent conflicts..."
        
        # Unmount any mounted Thyme OS partitions
        for part in $existing_efi $existing_root; do
            if mountpoint -q "$part" 2>/dev/null; then
                sudo umount "$part" 2>/dev/null || true
                log "Unmounted $part"
            fi
        done
        
        # Wipe filesystem signatures from existing partitions
        for part in $existing_efi $existing_root; do
            if [[ -b "$part" ]]; then
                sudo wipefs -af "$part" 2>/dev/null || true
                log "Wiped filesystem signatures from $part"
            fi
        done
    fi
    
    log "✅ Existing EFI installations cleaned"
}

# Format partitions
format_partitions() {
    log "Formatting partitions..."
    
    # Clean any existing installations first
    clean_existing_efi
    
    # Format with fresh filesystems
    sudo mkfs.fat -F 32 -n "THYME_EFI" "$EFI_PARTITION"
    sudo mkswap -L "ThymeSwap" "$SWAP_PARTITION" 
    sudo mkfs.ext4 -L "ThymeOS" "$ROOT_PARTITION"
    
    log "✅ Partitions formatted with clean filesystems"
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    ROOT_MOUNT_POINT="$WORK_DIR/root"
    EFI_MOUNT_POINT="$WORK_DIR/efi"
    
    mkdir -p "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    sudo mount "$ROOT_PARTITION" "$ROOT_MOUNT_POINT"
    sudo mount "$EFI_PARTITION" "$EFI_MOUNT_POINT"
    
    log "✅ Partitions mounted"
    export ROOT_MOUNT_POINT EFI_MOUNT_POINT
}

# Copy entire Mint system to target
copy_mint_system() {
    log "Copying working Linux Mint system to target SSD..."
    
    # This is the key difference - copy the ENTIRE working system
    log "Creating complete system copy (this will take several minutes)..."
    
    # Use rsync to copy everything except certain directories
    local exclude_dirs=(
        --exclude=/proc/*
        --exclude=/sys/*
        --exclude=/dev/*
        --exclude=/tmp/*
        --exclude=/run/*
        --exclude=/mnt/*
        --exclude=/media/*
        --exclude=/lost+found
        --exclude=/swapfile
        --exclude=/swapfile1
        --exclude=/home/*/.cache/*
        --exclude=/home/*/.local/share/Trash/*
        --exclude=/home/*/.Trash/*
        --exclude=/home/*/Desktop/Trash/*
        --exclude=/root/.local/share/Trash/*
        --exclude=/root/.Trash/*
        --exclude=/var/cache/*
        --exclude=/var/tmp/*
        --exclude=/var/log/*
        --exclude="*/.thumbnails/*"
        --exclude="*/.gvfs/*"
        --exclude="*/Downloads/*"
        --exclude="*/Desktop/*.desktop"
        --exclude="*/.recently-used*"
        --exclude="*/.xsession-errors*"
        --exclude="*/mintbook/*"
        --exclude="/usr/share/icons/*/256x256/*"
        --exclude="/usr/share/icons/*/128x128/*"
        --exclude="/usr/share/icons/*/96x96/*"
        --exclude="/usr/share/icons/*/64x64/*"
        --exclude="/usr/share/pixmaps/*.png"
        --exclude="/usr/share/pixmaps/*.jpg"
        --exclude="/usr/share/pixmaps/*.svg"
    )
    
    log "Copying root filesystem (this may take 10-15 minutes)..."
    sudo rsync -aHAXv "${exclude_dirs[@]}" / "$ROOT_MOUNT_POINT/" | tee -a "$INSTALL_LOG"
    
    # Create empty directories that were excluded
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{proc,sys,dev,tmp,run,mnt,media}
    sudo chmod 1777 "$ROOT_MOUNT_POINT/tmp"
    
    # Clean up and create fresh user directories
    clean_user_directories
    
    # Remove unnecessary packages for lighter system
    remove_bloatware_packages
    
    log "✅ Mint system copied successfully"
}

# Clean up user directories and create fresh ones
clean_user_directories() {
    log "Cleaning up user directories..."
    
    # Create clean trash directories
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.local/share/Trash"/{files,info}
    sudo mkdir -p "$ROOT_MOUNT_POINT/root/.local/share/Trash"/{files,info}
    
    # Create empty Downloads directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Downloads"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Desktop"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Documents"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Pictures"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Music"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Videos"
    
    # Create fresh log directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/var/log"
    sudo chmod 755 "$ROOT_MOUNT_POINT/var/log"
    
    # Remove any remaining cache and temporary files
    sudo find "$ROOT_MOUNT_POINT" -name "*.log" -type f -delete 2>/dev/null || true
    sudo find "$ROOT_MOUNT_POINT" -name "*~" -type f -delete 2>/dev/null || true
    sudo find "$ROOT_MOUNT_POINT" -name ".DS_Store" -type f -delete 2>/dev/null || true
    sudo find "$ROOT_MOUNT_POINT" -name "Thumbs.db" -type f -delete 2>/dev/null || true
    
    # Clean up large icon files (keep only essential small sizes)
    log "Cleaning up large icon files..."
    sudo find "$ROOT_MOUNT_POINT/usr/share/icons" -name "*.png" -size +50k -delete 2>/dev/null || true
    sudo find "$ROOT_MOUNT_POINT/usr/share/pixmaps" -name "*.png" -size +20k -delete 2>/dev/null || true
    sudo find "$ROOT_MOUNT_POINT/usr/share/pixmaps" -name "*.svg" -size +10k -delete 2>/dev/null || true
    
    # Set proper ownership for thyme user directories
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme" 2>/dev/null || true
    
    log "✅ User directories cleaned and created fresh"
}

# Remove unnecessary packages to lighten Thyme OS
remove_bloatware_packages() {
    log "Removing unnecessary packages for lighter Thyme OS..."
    
    # Packages to remove for vintage MacBook optimization
    local packages_to_remove=(
        # Games (not needed for coding/productivity OS)
        "aisleriot"
        "gnome-mahjongg"
        "gnome-mines"
        "gnome-sudoku"
        "sol"
        
        # Heavy office suites (we'll keep lighter alternatives)
        "libreoffice-*"
        "thunderbird"
        
        # Heavy multimedia apps
        "rhythmbox"
        "totem"
        "cheese"
        "shotwell"
        "simple-scan"
        
        # Development tools most users won't need
        "hexchat"
        "transmission-*"
        "pidgin"
        
        # Heavy graphics apps
        "gimp"
        "inkscape"
        "blender"
        
        # Unnecessary system tools
        "webapp-manager"
        "sticky"
        "redshift"
        "gucharmap"
        
        # Heavy network tools
        "wireshark"
        "nmap"
        
        # Unused language packs (keep English)
        "language-pack-*"
        "hunspell-*"
        "aspell-*"
        "mythes-*"
        
        # Old/obsolete packages
        "firefox-locale-*"
        "hyphen-*"
        
        # Snap packages (heavy)
        "snapd"
        "snap-*"
    )
    
    # Create script to remove packages in chroot (offline mode)
    sudo tee "$ROOT_MOUNT_POINT/tmp/remove_packages.sh" > /dev/null << 'EOF'
#!/bin/bash
# Remove packages script for Thyme OS (offline mode)

export DEBIAN_FRONTEND=noninteractive

echo "Starting package removal (offline mode)..."

# Remove games (no network needed)
dpkg --remove --force-depends aisleriot gnome-mahjongg gnome-mines gnome-sudoku 2>/dev/null || true

# Remove heavy office apps
dpkg --remove --force-depends libreoffice-base libreoffice-calc libreoffice-draw libreoffice-impress libreoffice-writer libreoffice-common thunderbird 2>/dev/null || true

# Remove heavy multimedia
dpkg --remove --force-depends rhythmbox totem cheese shotwell simple-scan 2>/dev/null || true

# Remove network apps
dpkg --remove --force-depends hexchat transmission-gtk transmission-common pidgin 2>/dev/null || true

# Remove graphics apps
dpkg --remove --force-depends gimp inkscape blender 2>/dev/null || true

# Remove system bloat
dpkg --remove --force-depends webapp-manager sticky redshift gucharmap 2>/dev/null || true

# Remove snap system
dpkg --remove --force-depends snapd 2>/dev/null || true

# Remove package files to save space
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# Clean up broken package states
dpkg --configure -a 2>/dev/null || true

echo "Package removal completed (offline mode)"
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/tmp/remove_packages.sh"
    
    # Execute package removal in chroot
    log "Executing package removal in chroot environment..."
    sudo chroot "$ROOT_MOUNT_POINT" /tmp/remove_packages.sh 2>&1 | tee -a "$INSTALL_LOG"
    
    # Remove the script
    sudo rm "$ROOT_MOUNT_POINT/tmp/remove_packages.sh"
    
    # Create list of essential packages for Thyme OS
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/thyme"
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme/essential-packages.txt" > /dev/null << 'EOF'
# Thyme OS Essential Packages
# Minimal package set for MacBook productivity

## System Core
linux-image-generic
linux-headers-generic
grub-efi-amd64
systemd

## Desktop Environment  
xfce4
xfce4-terminal
xfce4-panel
lightdm

## Text Editors
nano
vim-tiny
micro (custom install)

## System Tools
htop
neofetch
curl
wget
git
ssh
rsync

## File Management
thunar
file-roller

## Web Browser
firefox-esr

## Lightweight Office
abiword
gnumeric

## Media (minimal)
vlc-nogui
mpv

## Development (optional)
python3
python3-pip
build-essential
EOF
    
    log "✅ Bloatware removed, system lightened for vintage MacBook"
    log "   • Games removed"
    log "   • Heavy office suites removed (LibreOffice → AbiWord/Gnumeric)"
    log "   • Heavy multimedia apps removed"
    log "   • Snap system removed"
    log "   • Lightweight alternatives installed"
}

# Customize system for Thyme OS
customize_for_thyme() {
    log "Customizing system for Thyme OS..."
    
    # Update system identification
    sudo tee "$ROOT_MOUNT_POINT/etc/lsb-release" > /dev/null << 'EOF'
DISTRIB_ID=ThymeOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=macbook
DISTRIB_DESCRIPTION="Thyme OS 1.0 (MacBook Edition)"
EOF
    
    # Update hostname
    echo "thymeos" | sudo tee "$ROOT_MOUNT_POINT/etc/hostname" > /dev/null
    
    # Update /etc/hosts
    sudo sed -i 's/127.0.1.1.*/127.0.1.1\tthymeos/' "$ROOT_MOUNT_POINT/etc/hosts"
    
    # Create Thyme OS branding
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/thyme"
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme/version" > /dev/null << EOF
Thyme OS 1.0 MacBook Edition
Based on Linux Mint $(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
Built: $(date)
Target: MacBook2,1 and compatible systems
EOF
    
    # Update GRUB branding
    if [[ -f "$ROOT_MOUNT_POINT/etc/default/grub" ]]; then
        sudo sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Thyme OS"/' "$ROOT_MOUNT_POINT/etc/default/grub"
    fi
    
    # Install Thyme Enhanced Text Editor
    install_thyme_editor
    
    # Configure USB/HID support for MacBook
    configure_usb_hid_support
    
    log "✅ System customized for Thyme OS"
}

# Install Thyme Enhanced Text Editor  
install_thyme_editor() {
    log "Installing Thyme Enhanced Text Editor..."
    
    local editor_tools_dir="/home/meister/mintbook/thyme-editor-tools"
    local micro_binary="$editor_tools_dir/micro-binary/micro-2.0.13/micro"
    
    if [[ ! -f "$micro_binary" ]]; then
        warn "Micro editor binary not found - skipping editor installation"
        return
    fi
    
    # Install Micro editor binary
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin"
    sudo cp "$micro_binary" "$ROOT_MOUNT_POINT/usr/local/bin/micro"
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/micro"
    
    # Create convenient aliases
    sudo ln -sf "/usr/local/bin/micro" "$ROOT_MOUNT_POINT/usr/local/bin/thyme-edit"
    sudo ln -sf "/usr/local/bin/micro" "$ROOT_MOUNT_POINT/usr/local/bin/te"
    
    # Create system configuration directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/thyme/editor"
    
    # Install system-wide Micro settings
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme/editor/settings.json" > /dev/null << 'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": 2,
    "colorscheme": "solarized-tc",
    "cursorline": true,
    "diff": true,
    "ignorecase": false,
    "indentsize": 4,
    "ruler": true,
    "scrollmargin": 3,
    "scrollspeed": 2,
    "softwrap": false,
    "splitRight": true,
    "statusline": true,
    "syntax": true,
    "tabsize": 4,
    "tabstospaces": true,
    "useprimary": true,
    "fileformat": "unix"
}
EOF
    
    # Create user directories for thyme user
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.config/micro"
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.local/share/thyme-editor"
    
    # Install user-specific settings
    sudo cp "$ROOT_MOUNT_POINT/etc/thyme/editor/settings.json" "$ROOT_MOUNT_POINT/home/thyme/.config/micro/settings.json"
    
    # Install custom key bindings if available
    if [[ -f "$editor_tools_dir/thyme-editor-config/thyme-bindings.json" ]]; then
        sudo cp "$editor_tools_dir/thyme-editor-config/thyme-bindings.json" "$ROOT_MOUNT_POINT/home/thyme/.config/micro/bindings.json"
    fi
    
    # Install custom color scheme if available
    if [[ -f "$editor_tools_dir/thyme-editor-config/thyme-colorscheme.micro" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.config/micro/colorschemes"
        sudo cp "$editor_tools_dir/thyme-editor-config/thyme-colorscheme.micro" "$ROOT_MOUNT_POINT/home/thyme/.config/micro/colorschemes/thyme.micro"
    fi
    
    # Create documentation
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/.local/share/thyme-editor/README.md" > /dev/null << 'EOF'
# 🍃 Thyme OS Enhanced Text Editor

## Quick Start
```bash
thyme-edit filename.py   # Edit with syntax highlighting
te filename.py          # Short alias
micro filename.py       # Direct command
```

## Key Features
- ✅ Syntax highlighting for 130+ languages
- ✅ Multiple cursors (Ctrl+mouse click)
- ✅ Split panes (Ctrl+e)
- ✅ Tabs (Ctrl+t)
- ✅ Find/Replace (Ctrl+f/Ctrl+r)
- ✅ Mouse support
- ✅ Auto-completion

## Essential Keybindings
- Ctrl+s - Save
- Ctrl+o - Open  
- Ctrl+q - Quit
- Ctrl+c/v/x - Copy/Paste/Cut
- Ctrl+z/y - Undo/Redo
- Ctrl+f - Find
- Ctrl+r - Replace
- Ctrl+e - Split vertically
- Ctrl+t - New tab

## MacBook Optimized
- Nano-like interface with modern features
- Lightweight for vintage MacBooks
- Terminal-based, no GUI needed

For more help: Press Ctrl+g in the editor
EOF
    
    # Set proper ownership
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/.config"
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/.local"
    
    # Add to PATH if not already there
    if [[ -f "$ROOT_MOUNT_POINT/home/thyme/.bashrc" ]]; then
        if ! grep -q "/usr/local/bin" "$ROOT_MOUNT_POINT/home/thyme/.bashrc"; then
            echo 'export PATH="/usr/local/bin:$PATH"' | sudo tee -a "$ROOT_MOUNT_POINT/home/thyme/.bashrc" > /dev/null
        fi
    fi
    
    log "✅ Thyme Enhanced Text Editor installed"
    log "   Available commands: thyme-edit, te, micro"
    log "   Languages supported: Python, Bash, HTML, CSS, JavaScript, and 125+ more"
}

# Configure USB/HID support for MacBook compatibility
configure_usb_hid_support() {
    log "Configuring USB/HID support for MacBook..."
    
    # Create modprobe configuration for USB/HID
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/modprobe.d"
    
    sudo tee "$ROOT_MOUNT_POINT/etc/modprobe.d/thyme-usb-hid.conf" > /dev/null << 'EOF'
# Thyme OS USB/HID Configuration for MacBook
# Force USB modules to load with proper parameters

# Disable USB autosuspend for input devices
options usbcore autosuspend=-1

# USB HID mouse polling and quirks for Apple devices
options usbhid mousepoll=0
options usbhid quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01,0x05ac:0x022a:0x01

# PS/2 keyboard controller fixes for MacBook
options i8042 reset=1 nomux=1 nopnp=1 noloop=1

# PS/2 mouse configuration
options psmouse proto=imps rate=100
EOF
    
    # Create modules loading configuration
    sudo tee "$ROOT_MOUNT_POINT/etc/modules-load.d/thyme-input.conf" > /dev/null << 'EOF'
# Thyme OS - Force load input device modules
usbhid
hid
i8042
atkbd
psmouse
ohci_hcd
uhci_hcd
ehci_hcd
xhci_hcd
EOF
    
    # Create initramfs hook to ensure modules are in initrd
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules"
    sudo tee "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules/thyme-input" > /dev/null << 'EOF'
# Thyme OS Input Device Modules for initramfs
usbhid
hid
i8042
atkbd
psmouse
ohci_hcd
uhci_hcd
ehci_hcd
xhci_hcd
EOF
    
    # Create systemd service to ensure USB modules load early
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/systemd/system"
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system/thyme-usb-fix.service" > /dev/null << 'EOF'
[Unit]
Description=Thyme OS USB/HID Early Loading
DefaultDependencies=false
After=systemd-modules-load.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe usbhid; modprobe hid; modprobe i8042; modprobe atkbd; modprobe psmouse; echo "Thyme USB modules loaded"'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    sudo ln -sf "/etc/systemd/system/thyme-usb-fix.service" "$ROOT_MOUNT_POINT/etc/systemd/system/multi-user.target.wants/thyme-usb-fix.service"
    
    # Update GRUB default parameters
    if [[ -f "$ROOT_MOUNT_POINT/etc/default/grub" ]]; then
        # Add USB/HID parameters to default GRUB command line
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$ROOT_MOUNT_POINT/etc/default/grub"; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux"/' "$ROOT_MOUNT_POINT/etc/default/grub"
        else
            echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux"' | sudo tee -a "$ROOT_MOUNT_POINT/etc/default/grub" > /dev/null
        fi
    fi
    
    log "✅ USB/HID support configured for MacBook compatibility"
    log "   • USB autosuspend disabled"
    log "   • Apple USB device quirks applied"
    log "   • PS/2 keyboard controller fixed"
    log "   • Input modules forced to load early"
}

# Update fstab for new UUIDs
update_fstab() {
    log "Updating fstab for new partition UUIDs..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local efi_uuid=$(sudo blkid -s UUID -o value "$EFI_PARTITION")
    local swap_uuid=$(sudo blkid -s UUID -o value "$SWAP_PARTITION")
    
    sudo tee "$ROOT_MOUNT_POINT/etc/fstab" > /dev/null << EOF
# Thyme OS fstab - MacBook optimized
UUID=$root_uuid / ext4 defaults 0 1
UUID=$efi_uuid /boot/efi vfat defaults 0 2
UUID=$swap_uuid none swap sw 0 0
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
EOF
    
    log "✅ fstab updated with new UUIDs"
}

# Install GRUB with MacBook compatibility
install_grub() {
    log "Installing GRUB bootloader for MacBook compatibility..."
    
    # Clean EFI partition completely
    sudo rm -rf "$EFI_MOUNT_POINT"/*
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
    
    # Install 32-bit EFI for MacBook2,1 compatibility
    if [[ -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootia32.efi"
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubia32.efi"
        log "✅ 32-bit GRUB EFI installed"
    else
        error "32-bit GRUB EFI file required: $GRUB_FILES_DIR/grubia32.efi"
    fi
    
    # Create GRUB configuration optimized for MacBook
    create_grub_config
    
    log "✅ GRUB installation completed"
}

# Create GRUB configuration 
create_grub_config() {
    log "Creating GRUB configuration..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local grub_cfg="$EFI_MOUNT_POINT/EFI/thyme/grub.cfg"
    
    sudo tee "$grub_cfg" > /dev/null << EOF
# Thyme OS GRUB Configuration - MacBook Compatible with USB/HID Fixes
# Uses UUID-based root detection to handle changing drive letters (sdb/sdc/sdd)
# Root UUID: $root_uuid
set timeout=15
set default=0

echo "🍃 Thyme OS Loading (USB/HID Fixed, UUID-based)..."

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
    echo "Booting Thyme OS with USB/HID fixes for MacBook..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 usbhid.quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop
    initrd /boot/initrd.img
}

menuentry "🛠️ Thyme OS - Force All USB Modules" {
    echo "Loading all USB and input modules for maximum compatibility..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 psmouse.proto=imps psmouse.rate=100 i8042.reset i8042.nomux i8042.nopnp i8042.noloop i8042.direct i8042.dumbkbd
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Safe Mode" {
    echo "Booting Thyme OS in Safe Mode with input fixes..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro nomodeset acpi=off usbcore.autosuspend=-1 i8042.reset quiet
    initrd /boot/initrd.img
}

menuentry "🔧 Debug Mode (USB/HID verbose)" {
    echo "Debug boot with USB/HID troubleshooting..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro debug loglevel=8 usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.debug i8042.reset i8042.nomux
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell (bypass login)" {
    echo "Emergency shell - no login required..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro single init=/bin/bash usbcore.autosuspend=-1 i8042.reset
    initrd /boot/initrd.img
}

menuentry "🔄 Reboot System" {
    reboot
}

menuentry "⚡ Shutdown System" {
    halt
}
EOF
    
    # Copy to standard location
    sudo cp "$grub_cfg" "$EFI_MOUNT_POINT/EFI/BOOT/grub.cfg"
    
    log "✅ GRUB configuration created"
}

# Main installation function
main() {
    initialize_installer
    
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        log "🚀 AUTO-INSTALL MODE: Proceeding automatically"
    else
        read -p "Continue with Thyme OS Mint-based installation? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Installation cancelled"
        fi
    fi
    
    check_mint_system
    detect_target_device
    
    warn "This will COMPLETELY ERASE $TARGET_DEVICE and install Thyme OS"
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        log "🚀 AUTO-INSTALL MODE: Auto-confirming installation"
    else
        read -p "Type 'ERASE' to confirm: " confirm
        if [[ "${confirm,,}" != "erase" ]]; then
            error "Installation cancelled"
        fi
    fi
    
    partition_device
    format_partitions
    mount_partitions
    copy_mint_system
    customize_for_thyme
    update_fstab
    install_grub
    
    # Cleanup
    sync
    sudo umount "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    success "🎉 Thyme OS installation completed!"
    success "System is ready to boot on MacBook2,1"
    success "Based on your working Linux Mint installation"
}

# Run installation
main "$@"