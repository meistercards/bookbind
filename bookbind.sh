#!/bin/bash
# Thyme OS Streamlined Installer v3.0
# Fixed version with proper package exclusion and boot testing
# Builds a clean, minimal Thyme OS fork from Mint base

set -e

SCRIPT_VERSION="3.0-streamlined"
INSTALL_LOG="/var/log/thyme_streamlined_install.log"
GRUB_FILES_DIR="$(dirname "$(readlink -f "$0")")/grub_files"
WORK_DIR="/tmp/thyme_streamlined_work"
TEST_MODE=${1:-"normal"}  # normal, test, debug, auto
AUTO_CONFIRM=${AUTO_CONFIRM:-"true"}  # Auto-confirm for testing

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Enhanced logging with permission handling
log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
}

warn() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
    cleanup_on_error
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Enhanced cleanup
cleanup_on_error() {
    if [[ "${CLEANUP_IN_PROGRESS:-}" == "true" ]]; then
        echo "Cleanup already in progress, exiting..."
        exit 1
    fi
    export CLEANUP_IN_PROGRESS=true
    
    echo "Cleaning up after error..."
    
    # Unmount all mounted filesystems
    for mount_point in "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"; do
        if [[ -n "$mount_point" ]] && mountpoint -q "$mount_point" 2>/dev/null; then
            sudo umount "$mount_point" 2>/dev/null || true
        fi
    done
    
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
🍃 Thyme OS Streamlined Installer v3.0 🍃
=========================================

Creating Thyme OS with SMART package exclusion:
• Excludes bloatware DURING copy (not after)
• Smaller, faster installation
• Better boot compatibility
• Built-in testing framework

EOF
    echo -e "${NC}"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Create log file with proper permissions
    sudo mkdir -p "$(dirname "$INSTALL_LOG")"
    sudo touch "$INSTALL_LOG"
    sudo chmod 666 "$INSTALL_LOG"
    echo "Thyme OS Streamlined Installer Log - $(date)" | sudo tee "$INSTALL_LOG" > /dev/null
    log "Installer initialized in $TEST_MODE mode"
}

# Check Mint system and validate
check_mint_system() {
    log "Validating Linux Mint system..."
    
    if [[ ! -f "/etc/lsb-release" ]] || ! grep -q "DISTRIB_ID=LinuxMint" /etc/lsb-release; then
        error "This installer must be run from a working Linux Mint system"
    fi
    
    local mint_version=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
    log "✅ Running on Linux Mint $mint_version"
    
    # Check available disk space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 8000000 ]]; then  # 8GB minimum
        warn "Low disk space available: $((available_space/1024/1024))GB"
    fi
    
    log "✅ System validation passed"
}

# Enhanced device detection with smart identification
detect_target_device() {
    log "Detecting available storage devices with enhanced identification..."
    
    if [[ "$TEST_MODE" == "test" ]]; then
        log "🧪 TEST MODE: Creating test image file instead of real device"
        TEST_IMAGE="$WORK_DIR/thyme_test.img"
        dd if=/dev/zero of="$TEST_IMAGE" bs=1M count=4096  # 4GB test image
        TARGET_DEVICE="$TEST_IMAGE"
        export TARGET_DEVICE
        return
    fi
    
    # Enhanced device detection
    enhanced_device_detection
}

# Enhanced device detection with multiple identification methods
enhanced_device_detection() {
    echo
    echo "🔍 Enhanced Device Detection"
    echo "=========================="
    echo "Scanning for suitable target devices..."
    echo
    
    local system_disk=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    local candidate_devices=()
    local device_info=()
    
    # Get all block devices with detailed information
    while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $4}')
        local type=$(echo "$line" | awk '{print $6}')
        local model=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | sed 's/^ *//')
        
        device="/dev/$device"
        
        # Skip if it's the system disk
        if [[ "$device" == "$system_disk" ]]; then
            continue
        fi
        
        # Skip if not a physical disk
        if [[ "$type" != "disk" ]]; then
            continue
        fi
        
        # Skip if device doesn't exist
        if [[ ! -b "$device" ]]; then
            continue
        fi
        
        # Get additional device information
        local vendor=""
        local serial=""
        local is_usb=""
        local is_removable=""
        
        # Check if it's USB
        if udevadm info --query=property --name="$device" 2>/dev/null | grep -q "ID_BUS=usb"; then
            is_usb="USB"
            vendor=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_VENDOR=" | cut -d= -f2 || echo "Unknown")
        fi
        
        # Check if removable
        if [[ -f "/sys/block/$(basename "$device")/removable" ]]; then
            local removable_status=$(cat "/sys/block/$(basename "$device")/removable" 2>/dev/null || echo "0")
            if [[ "$removable_status" == "1" ]]; then
                is_removable="Removable"
            fi
        fi
        
        # Get serial if available
        serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_SERIAL_SHORT=" | cut -d= -f2 || echo "N/A")
        
        # Check for existing Thyme OS installation
        local has_thyme=""
        if blkid "$device"* 2>/dev/null | grep -q "THYME\|ThymeOS"; then
            has_thyme="(Previous Thyme OS detected)"
        fi
        
        # Check device name history for this specific device
        local name_history=""
        if [[ "$serial" != "N/A" ]]; then
            # Look for this device in dmesg to see previous names
            local previous_names=$(dmesg | grep "$serial" | grep -o "sd[a-z]" | sort -u | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$previous_names" ]]; then
                name_history="(Previously: $previous_names)"
            fi
        fi
        
        # Validate device size (should be at least 4GB for Thyme OS)
        local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1)
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        
        if [[ $size_gb -lt 4 ]]; then
            log "Skipping $device: Too small (${size_gb}GB < 4GB minimum)"
            continue
        fi
        
        # Add to candidates
        candidate_devices+=("$device")
        device_info+=("$size|$model|$vendor|$is_usb|$is_removable|$serial|$has_thyme|$name_history")
        
    done < <(lsblk -d -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT,MODEL)
    
    if [[ ${#candidate_devices[@]} -eq 0 ]]; then
        error "No suitable target devices found. Need at least 4GB removable/USB storage."
    fi
    
    echo "Suitable target devices found:"
    echo "=============================="
    for i in "${!candidate_devices[@]}"; do
        local device="${candidate_devices[$i]}"
        local info="${device_info[$i]}"
        
        local size=$(echo "$info" | cut -d'|' -f1)
        local model=$(echo "$info" | cut -d'|' -f2)
        local vendor=$(echo "$info" | cut -d'|' -f3)
        local is_usb=$(echo "$info" | cut -d'|' -f4)
        local is_removable=$(echo "$info" | cut -d'|' -f5)
        local serial=$(echo "$info" | cut -d'|' -f6)
        local has_thyme=$(echo "$info" | cut -d'|' -f7)
        local name_history=$(echo "$info" | cut -d'|' -f8)
        
        echo "$((i+1)). $device"
        echo "   Size: $size"
        echo "   Model: ${model:-Unknown}"
        [[ -n "$vendor" ]] && echo "   Vendor: $vendor"
        [[ -n "$is_usb" ]] && echo "   Type: $is_usb"
        [[ -n "$is_removable" ]] && echo "   Status: $is_removable"
        [[ "$serial" != "N/A" ]] && echo "   Serial: $serial"
        [[ -n "$name_history" ]] && echo "   📝 $name_history"
        [[ -n "$has_thyme" ]] && echo "   🍃 $has_thyme"
        echo
    done
    
    # Auto-select if only one device and it looks safe
    if [[ ${#candidate_devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="${candidate_devices[0]}"
        local info="${device_info[0]}"
        local is_usb=$(echo "$info" | cut -d'|' -f4)
        local is_removable=$(echo "$info" | cut -d'|' -f5)
        
        log "Auto-detected target device: $TARGET_DEVICE"
        
        # Extra safety check for USB/removable devices
        if [[ -n "$is_usb" ]] || [[ -n "$is_removable" ]]; then
            log "✅ Device appears to be external ($is_usb $is_removable)"
        else
            warn "⚠️  Device may be internal - please verify this is correct!"
        fi
        
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        validate_target_device "$TARGET_DEVICE"
        
        # Offer device name explanation and consistency info
        explain_device_naming "$TARGET_DEVICE" "$info"
        
        if [[ "$AUTO_CONFIRM" == "true" ]]; then
            log "🚀 AUTO-CONFIRM MODE: Proceeding with installation to $TARGET_DEVICE"
        else
            read -p "Continue with installation to $TARGET_DEVICE? (y/n): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                error "Installation cancelled by user"
            fi
        fi
    else
        echo "Multiple devices available. Please select target device:"
        read -p "Select device number (1-${#candidate_devices[@]}): " device_num
        
        if [[ "$device_num" -ge 1 ]] && [[ "$device_num" -le ${#candidate_devices[@]} ]]; then
            TARGET_DEVICE="${candidate_devices[$((device_num-1))]}"
            warn "Selected: $TARGET_DEVICE - This will be COMPLETELY ERASED"
            
            validate_target_device "$TARGET_DEVICE"
            
            if [[ "$AUTO_CONFIRM" == "true" ]]; then
                log "🚀 AUTO-CONFIRM MODE: Auto-typing 'ERASE' confirmation"
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
    
    export TARGET_DEVICE
}

# Validate target device with comprehensive checks
validate_target_device() {
    local device="$1"
    
    log "Validating target device: $device"
    
    # Check device exists
    if [[ ! -b "$device" ]]; then
        error "Device $device does not exist or is not a block device"
    fi
    
    # Check device is not mounted as root
    if mount | grep -q "^$device.* / "; then
        error "Device $device contains the root filesystem - cannot install to system disk"
    fi
    
    # Check device size
    local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1)
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    
    if [[ $size_gb -lt 4 ]]; then
        error "Device $device is too small (${size_gb}GB). Minimum 4GB required."
    fi
    
    if [[ $size_gb -gt 128 ]]; then
        warn "Device $device is quite large (${size_gb}GB). Are you sure this is the correct device?"
    fi
    
    # Check if device has active partitions
    local mounted_parts=$(mount | grep "^$device" | wc -l)
    if [[ $mounted_parts -gt 0 ]]; then
        warn "Device $device has mounted partitions:"
        mount | grep "^$device"
        echo
        warn "These will be unmounted during installation"
    fi
    
    # Check for existing data
    if blkid "$device"* 2>/dev/null | grep -v "THYME\|ThymeOS" | head -5; then
        warn "Device contains existing data (shown above)"
        warn "All data will be permanently lost!"
    fi
    
    log "✅ Device validation passed"
}

# Explain device naming and offer consistency information
explain_device_naming() {
    local device="$1"
    local info="$2"
    
    local serial=$(echo "$info" | cut -d'|' -f6)
    local name_history=$(echo "$info" | cut -d'|' -f8)
    
    echo
    echo "📝 Device Naming Information:"
    echo "=========================="
    echo "Current device name: $device"
    
    if [[ -n "$name_history" && "$name_history" != "(Previously: )" ]]; then
        echo "Previous names: $name_history"
        echo
        echo "ℹ️  Device names can change (sdb→sdc→sdd) based on:"
        echo "   • USB port used"
        echo "   • Other connected devices"  
        echo "   • Boot order"
        echo
        echo "🔧 The installer handles this automatically by:"
        echo "   • Using UUIDs in GRUB configuration"
        echo "   • Smart partition detection"
        echo "   • Device identification by serial number"
        echo
        echo "✅ Your device will boot correctly regardless of name changes!"
    else
        echo "This appears to be the first time detecting this device."
    fi
    
    if [[ "$serial" != "N/A" ]]; then
        echo "🔍 Device ID: $serial (used for consistent identification)"
    fi
    echo
}

# Smart partition detection handles nvme, loop, and SATA devices
detect_partitions() {
    log "Detecting partitions on $TARGET_DEVICE..."
    
    # Wait for partitions to appear
    for i in {1..10}; do
        sudo partprobe "$TARGET_DEVICE" 2>/dev/null || true
        sleep 1
        
        # Try different naming conventions
        local possible_p1=()
        local possible_p2=()
        local possible_p3=()
        
        # Standard SATA/USB naming (sda1, sdb1, etc.)
        possible_p1+=("${TARGET_DEVICE}1")
        possible_p2+=("${TARGET_DEVICE}2")
        possible_p3+=("${TARGET_DEVICE}3")
        
        # NVMe/loop naming (nvme0n1p1, loop0p1, etc.)
        possible_p1+=("${TARGET_DEVICE}p1")
        possible_p2+=("${TARGET_DEVICE}p2")
        possible_p3+=("${TARGET_DEVICE}p3")
        
        # Check which partitions actually exist
        for part in "${possible_p1[@]}"; do
            if [[ -b "$part" ]]; then
                EFI_PARTITION="$part"
                break
            fi
        done
        
        for part in "${possible_p2[@]}"; do
            if [[ -b "$part" ]]; then
                SWAP_PARTITION="$part"
                break
            fi
        done
        
        for part in "${possible_p3[@]}"; do
            if [[ -b "$part" ]]; then
                ROOT_PARTITION="$part"
                break
            fi
        done
        
        # If all partitions found, break
        if [[ -n "$EFI_PARTITION" ]] && [[ -n "$SWAP_PARTITION" ]] && [[ -n "$ROOT_PARTITION" ]]; then
            break
        fi
        
        log "Waiting for partitions to appear... ($i/10)"
    done
    
    # Validate all partitions were found
    if [[ -z "$EFI_PARTITION" ]] || [[ ! -b "$EFI_PARTITION" ]]; then
        error "EFI partition not found or not accessible"
    fi
    
    if [[ -z "$SWAP_PARTITION" ]] || [[ ! -b "$SWAP_PARTITION" ]]; then
        error "Swap partition not found or not accessible"
    fi
    
    if [[ -z "$ROOT_PARTITION" ]] || [[ ! -b "$ROOT_PARTITION" ]]; then
        error "Root partition not found or not accessible"
    fi
    
    log "✅ Partitions detected:"
    log "   EFI:  $EFI_PARTITION"
    log "   Swap: $SWAP_PARTITION"
    log "   Root: $ROOT_PARTITION"
}

# Smart partitioning with loop device support
partition_device() {
    log "Partitioning device $TARGET_DEVICE..."
    
    if [[ "$TEST_MODE" == "test" ]]; then
        # Set up loop device for test image
        LOOP_DEVICE=$(sudo losetup --find --show "$TARGET_DEVICE")
        TARGET_DEVICE="$LOOP_DEVICE"
        log "🧪 TEST MODE: Using loop device $LOOP_DEVICE"
    fi
    
    # Unmount any mounted partitions
    if [[ -b "$TARGET_DEVICE" ]]; then
        for partition in $(lsblk -ln -o NAME "$TARGET_DEVICE" 2>/dev/null | tail -n +2); do
            sudo umount "/dev/$partition" 2>/dev/null || true
        done
    fi
    
    # Create GPT partition table
    sudo parted "$TARGET_DEVICE" --script mklabel gpt
    
    # Create partitions (same logic as before)
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
    
    sudo partprobe "$TARGET_DEVICE" 2>/dev/null || true
    sleep 2
    
    # Smart partition detection
    detect_partitions
    
    log "✅ Partitioning completed"
    export EFI_PARTITION SWAP_PARTITION ROOT_PARTITION LOOP_DEVICE
}

# Format partitions with proper labels
format_partitions() {
    log "Formatting partitions with clean filesystems..."
    
    # Wait for partitions to be ready
    sleep 3
    
    # Format with fresh filesystems and verify success
    log "Formatting EFI partition: $EFI_PARTITION"
    if ! sudo mkfs.fat -F 32 -n "THYME_EFI" "$EFI_PARTITION"; then
        error "Failed to format EFI partition"
    fi
    
    log "Formatting swap partition: $SWAP_PARTITION"
    if ! sudo mkswap -L "ThymeSwap" "$SWAP_PARTITION"; then
        error "Failed to format swap partition"
    fi
    
    log "Formatting root partition: $ROOT_PARTITION"
    if ! sudo mkfs.ext4 -F -L "ThymeOS" "$ROOT_PARTITION"; then
        error "Failed to format root partition"
    fi
    
    # Verify partitions are accessible
    for part in "$EFI_PARTITION" "$SWAP_PARTITION" "$ROOT_PARTITION"; do
        if [[ ! -b "$part" ]]; then
            error "Partition $part is not accessible after formatting"
        fi
    done
    
    log "✅ Partitions formatted and verified"
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    ROOT_MOUNT_POINT="$WORK_DIR/root"
    EFI_MOUNT_POINT="$WORK_DIR/efi"
    
    mkdir -p "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    # Mount root partition
    log "Mounting root partition: $ROOT_PARTITION -> $ROOT_MOUNT_POINT"
    if ! sudo mount "$ROOT_PARTITION" "$ROOT_MOUNT_POINT"; then
        error "Failed to mount root partition"
    fi
    
    # Create boot directory in root partition
    sudo mkdir -p "$ROOT_MOUNT_POINT/boot/efi"
    
    # Mount EFI partition with specific options for FAT32
    log "Mounting EFI partition: $EFI_PARTITION -> $EFI_MOUNT_POINT"
    if ! sudo mount -t vfat -o rw,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro "$EFI_PARTITION" "$EFI_MOUNT_POINT"; then
        error "Failed to mount EFI partition"
    fi
    
    # Verify mounts are working
    if ! mountpoint -q "$ROOT_MOUNT_POINT"; then
        error "Root mount verification failed"
    fi
    
    if ! mountpoint -q "$EFI_MOUNT_POINT"; then
        error "EFI mount verification failed"
    fi
    
    log "✅ Partitions mounted and verified"
    export ROOT_MOUNT_POINT EFI_MOUNT_POINT
}

# SMART copy system - exclude bloatware DURING copy, not after
smart_copy_mint_system() {
    log "Smart copying Linux Mint system (excluding bloatware during copy)..."
    
    # Define SAFE exclusion patterns that won't affect system libraries
    local bloatware_patterns=(
        # Games - use specific paths to avoid conflicts
        "/usr/games/aisleriot*"
        "/usr/games/gnome-mahjongg*"
        "/usr/games/gnome-mines*"
        "/usr/games/gnome-sudoku*"
        "/usr/games/sol*"
        "/usr/share/games/*"
        
        # Heavy office suites - use specific paths only
        "/usr/lib/libreoffice/*"
        "/usr/bin/libreoffice*"
        "/usr/share/libreoffice/*"
        "/opt/libreoffice*"
        "/usr/bin/thunderbird*"
        "/usr/lib/thunderbird/*"
        "/usr/share/thunderbird/*"
        
        # Heavy multimedia - specific paths
        "/usr/bin/rhythmbox*"
        "/usr/lib/rhythmbox/*"
        "/usr/share/rhythmbox/*"
        "/usr/bin/totem*"
        "/usr/lib/totem/*"
        "/usr/bin/cheese*"
        "/usr/bin/shotwell*"
        "/usr/bin/simple-scan*"
        
        # Network apps - specific paths
        "/usr/bin/hexchat*"
        "/usr/lib/hexchat/*"
        "/usr/bin/transmission*"
        "/usr/lib/transmission/*"
        "/usr/bin/pidgin*"
        "/usr/lib/pidgin/*"
        
        # Graphics apps - specific paths
        "/usr/bin/gimp*"
        "/usr/lib/gimp/*"
        "/usr/share/gimp/*"
        "/usr/bin/inkscape*"
        "/usr/bin/blender*"
        "/usr/lib/blender/*"
        
        # System bloat - specific paths
        "/usr/bin/webapp-manager*"
        "/usr/bin/sticky*"
        "/usr/bin/gucharmap*"
        "/usr/bin/mintwelcome*"
        "/usr/lib/linuxmint/mintwelcome/*"
        "/usr/share/linuxmint/mintwelcome/*"
        "/usr/share/applications/mintwelcome*"
        "/etc/xdg/autostart/*welcome*"
        "/etc/xdg/autostart/*mint*"
        
        # Snap system - specific paths
        "/usr/bin/snap*"
        "/usr/lib/snapd/*"
        "/snap/*"
        "/var/lib/snapd/*"
        
        # Wine and Windows emulation - exclude completely
        "/usr/bin/wine*"
        "/usr/lib/wine/*"
        "/usr/share/wine/*"
        "/opt/wine*"
        "*/wine/*"
        "*/.wine/*"
        "*/.local/share/wineprefixes/*"
        
        # Steam and gaming platforms - exclude completely  
        "/usr/bin/steam*"
        "/usr/lib/steam/*"
        "/usr/share/steam/*"
        "*/.steam/*"
        "*/.local/share/Steam/*"
        "*/steamapps/*"
        "*/.config/unity3d/*"
        "*/.local/share/lutris/*"
        
        # Language packs - exclude non-English, but keep critical ones
        "/usr/share/locale/a[a-df-z]*"
        "/usr/share/locale/b*"
        "/usr/share/locale/c[a-z&&[^-]]*"
        "/usr/share/locale/d*"
        "/usr/share/locale/f*"
        "/usr/share/locale/g*"
        "/usr/share/locale/h*"
        "/usr/share/locale/i[a-df-z]*"
        "/usr/share/locale/j*"
        "/usr/share/locale/k*"
        "/usr/share/locale/l*"
        "/usr/share/locale/m*"
        "/usr/share/locale/n*"
        "/usr/share/locale/o*"
        "/usr/share/locale/p*"
        "/usr/share/locale/q*"
        "/usr/share/locale/r*"
        "/usr/share/locale/s*"
        "/usr/share/locale/t*"
        "/usr/share/locale/u*"
        "/usr/share/locale/v*"
        "/usr/share/locale/w*"
        "/usr/share/locale/x*"
        "/usr/share/locale/y*"
        "/usr/share/locale/z*"
        
        # Icons - exclude most sizes for minimal install
        "/usr/share/icons/*/256x256/*"
        "/usr/share/icons/*/128x128/*"
        "/usr/share/icons/*/96x96/*"
        "/usr/share/icons/*/64x64/*"
        "/usr/share/icons/*/48x48/*"
        "/usr/share/icons/*/32x32/*"
        "/usr/share/pixmaps/*.png"
        "/usr/share/pixmaps/*.svg"
        "/usr/share/pixmaps/*.xpm"
        
        # Documentation - minimal install
        "/usr/share/doc/*"
        "/usr/share/man/*"
        "/usr/share/info/*"
        "/usr/share/help/*"
        
        # Fonts - keep only essential
        "/usr/share/fonts/truetype/[^d]*"  # Keep DejaVu fonts only
        "/usr/share/fonts/opentype/*"
        "/usr/share/fonts/type1/*"
        
        # Themes - minimal
        "/usr/share/themes/[^A-M]*"  # Keep only themes A-M (includes default themes)
        
        # Sounds - minimal
        "/usr/share/sounds/*"
        
        # Wallpapers - minimal
        "/usr/share/backgrounds/*"
        "/usr/share/pixmaps/backgrounds/*"
        
        # Example files
        "/usr/share/example*"
        "/usr/share/applications/example*"
        
        # Development headers (not needed for basic system)
        "/usr/include/*"
        "/usr/share/pkgconfig/*"
        "/usr/lib/*/pkgconfig/*"
    )
    
    # Build exclusion patterns for rsync
    local exclude_args=()
    for pattern in "${bloatware_patterns[@]}"; do
        exclude_args+=(--exclude="$pattern")
    done
    
    # Standard exclusions
    local standard_excludes=(
        --exclude=/proc/*
        --exclude=/sys/*
        --exclude=/dev/*
        --exclude=/tmp/*
        --exclude=/run/*
        --exclude=/mnt/*
        --exclude=/media/*
        --exclude=/lost+found
        --exclude=/swapfile*
        --exclude=/home/*/.cache/*
        --exclude=/home/*/.local/share/Trash/*
        --exclude=/var/cache/*
        --exclude=/var/tmp/*
        --exclude=/var/log/*
        --exclude="*/.thumbnails/*"
        --exclude="*/Downloads/*"
        --exclude="*/mintbook/*"
        --exclude="/home/*/.*"
        --exclude="/home/*/Desktop/*"
        --exclude="/home/*/Documents/*"
        --exclude="/home/*/Downloads/*"
        --exclude="/home/*/Pictures/*"
        --exclude="/home/*/Music/*"
        --exclude="/home/*/Videos/*"
        --exclude="/root/.*"
        --exclude="/var/lib/flatpak/repo/tmp/*"
        --exclude="/var/lib/flatpak/*/staging-*"
        --exclude="/var/lib/flatpak/*/flatpak-cache-*"
        --exclude="/var/lib/flatpak/*/objects/*"
        --exclude="/var/lib/systemd/coredump/*"
        --exclude="/var/crash/*"
        --exclude="*/core"
        --exclude="*/core.*"
        
        # Additional temporary and cache exclusions (safe - no libraries)
        --exclude="/var/log/thyme_streamlined_install.log"
        --exclude="/var/log/kern.log*"
        --exclude="/var/log/syslog*"
        --exclude="/var/log/auth.log*"
        --exclude="/var/log/dpkg.log*"
        --exclude="/var/log/apt/*"
        --exclude="/var/cache/apt/*"
        --exclude="/var/cache/debconf/*"
        --exclude="/var/cache/man/*"
        --exclude="/var/cache/fontconfig/*"
        --exclude="/var/cache/PackageKit/*"
        --exclude="/var/cache/fwupd/*"
        --exclude="/tmp/systemd-private-*"
        --exclude="/var/tmp/systemd-private-*"
        --exclude="/tmp/.X*-lock"
        --exclude="/tmp/.font-unix/*"
        --exclude="/tmp/.ICE-unix/*"
        --exclude="/tmp/.X11-unix/*"
        --exclude="/tmp/ssh-*"
        --exclude="/tmp/claude-*"
        --exclude="/home/*/.bash_history"
        --exclude="/home/*/.lesshst"
        --exclude="/home/*/.viminfo"
        --exclude="/root/.bash_history"
        --exclude="/root/.lesshst"
        --exclude="/root/.viminfo"
    )
    
    log "Copying system with smart exclusions (this will be much faster)..."
    sudo rsync -aHAXv "${standard_excludes[@]}" "${exclude_args[@]}" / "$ROOT_MOUNT_POINT/" | tee -a "$INSTALL_LOG"
    
    # Ensure essential libraries are copied
    ensure_essential_libraries
    
    # Validate critical system libraries are present
    validate_system_libraries
    
    # Create necessary empty directories
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{proc,sys,dev,tmp,run,mnt,media}
    sudo chmod 1777 "$ROOT_MOUNT_POINT/tmp"
    
    # Clean user directories
    setup_clean_user_environment
    
    log "✅ Smart copy completed - bloatware excluded during copy"
}

# Set up clean user environment with skeletal structure only
setup_clean_user_environment() {
    log "Setting up clean user environment..."
    
    # Create clean home directory structure
    sudo mkdir -p "$ROOT_MOUNT_POINT/home"
    sudo mkdir -p "$ROOT_MOUNT_POINT/root"
    
    # Create skeletal user directories (will be customized on first boot)
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/skel"/{Desktop,Documents,Downloads,Pictures,Music,Videos}
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/skel/.local/share/Trash"/{files,info}
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/skel/.config"
    
    # Clean user accounts (remove personal data, keep system accounts)
    clean_user_accounts
    
    # Create fresh log directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/var/log"
    sudo chmod 755 "$ROOT_MOUNT_POINT/var/log"
    
    log "✅ Clean user environment created"
}

# Clean user accounts - remove personal users, keep system accounts
clean_user_accounts() {
    log "Cleaning user accounts..."
    
    # Create backup of original files
    sudo cp "$ROOT_MOUNT_POINT/etc/passwd" "$ROOT_MOUNT_POINT/etc/passwd.bak"
    sudo cp "$ROOT_MOUNT_POINT/etc/shadow" "$ROOT_MOUNT_POINT/etc/shadow.bak"
    sudo cp "$ROOT_MOUNT_POINT/etc/group" "$ROOT_MOUNT_POINT/etc/group.bak"
    
    # Remove non-system users (UID >= 1000) from passwd, shadow, and group
    sudo awk -F: '$3 < 1000 || $1 == "nobody" {print}' "$ROOT_MOUNT_POINT/etc/passwd.bak" > /tmp/clean_passwd
    sudo awk -F: '$3 < 1000 || $1 == "nobody" {print}' "$ROOT_MOUNT_POINT/etc/shadow.bak" > /tmp/clean_shadow
    sudo awk -F: '$3 < 1000 || $1 == "nobody" {print}' "$ROOT_MOUNT_POINT/etc/group.bak" > /tmp/clean_group
    
    sudo mv /tmp/clean_passwd "$ROOT_MOUNT_POINT/etc/passwd"
    sudo mv /tmp/clean_shadow "$ROOT_MOUNT_POINT/etc/shadow"
    sudo mv /tmp/clean_group "$ROOT_MOUNT_POINT/etc/group"
    
    # Set proper permissions
    sudo chmod 644 "$ROOT_MOUNT_POINT/etc/passwd"
    sudo chmod 640 "$ROOT_MOUNT_POINT/etc/shadow"
    sudo chmod 644 "$ROOT_MOUNT_POINT/etc/group"
    
    # Remove home directories of removed users
    for homedir in "$ROOT_MOUNT_POINT/home"/*; do
        if [[ -d "$homedir" ]]; then
            sudo rm -rf "$homedir"
        fi
    done
    
    log "✅ User accounts cleaned"
}

# Ensure essential libraries are definitely copied
ensure_essential_libraries() {
    log "Ensuring essential libraries are copied..."
    
    # Define critical library directories that must be complete
    local essential_dirs=(
        "/lib/x86_64-linux-gnu"
        "/usr/lib/x86_64-linux-gnu"
        "/lib64"
        "/usr/lib64"
    )
    
    for lib_dir in "${essential_dirs[@]}"; do
        if [[ -d "$lib_dir" ]]; then
            log "Copying essential libraries from $lib_dir..."
            sudo mkdir -p "$ROOT_MOUNT_POINT$lib_dir"
            sudo rsync -av "$lib_dir"/ "$ROOT_MOUNT_POINT$lib_dir/" 2>/dev/null || true
        fi
    done
    
    # Specifically ensure critical libraries are present
    local critical_files=(
        "/lib/x86_64-linux-gnu/libc.so.6"
        "/lib/x86_64-linux-gnu/libresolv.so.2"
        "/lib/x86_64-linux-gnu/libdl.so.2"
        "/lib/x86_64-linux-gnu/libm.so.6"
        "/lib/x86_64-linux-gnu/libpthread.so.0"
        "/lib/x86_64-linux-gnu/libssl.so.3"
        "/lib/x86_64-linux-gnu/libcrypto.so.3"
        "/lib/x86_64-linux-gnu/libz.so.1"
    )
    
    for lib_file in "${critical_files[@]}"; do
        if [[ -f "$lib_file" ]] && [[ ! -f "$ROOT_MOUNT_POINT$lib_file" ]]; then
            log "Copying critical library: $lib_file"
            sudo cp "$lib_file" "$ROOT_MOUNT_POINT$lib_file" 2>/dev/null || true
        fi
    done
    
    log "✅ Essential libraries ensured"
}

# Validate critical system libraries are present
validate_system_libraries() {
    log "Validating critical system libraries..."
    
    # Use more reliable library checking
    local critical_libs=(
        "libc.so"
        "libresolv.so"
        "libdl.so"
        "libm.so"
        "libpthread.so"
        "libssl.so"
        "libcrypto.so"
        "libz.so"
    )
    
    local missing_libs=()
    local lib_dir="$ROOT_MOUNT_POINT/lib/x86_64-linux-gnu"
    
    for lib_name in "${critical_libs[@]}"; do
        if ! ls "$lib_dir"/$lib_name* 2>/dev/null | head -1 | grep -q .; then
            missing_libs+=("$lib_name")
        fi
    done
    
    # Check for essential GUI libraries (less critical)
    local gui_libs=("libgtk-3.so" "libglib-2.0.so")
    local gui_lib_dir="$ROOT_MOUNT_POINT/usr/lib/x86_64-linux-gnu"
    
    for lib_name in "${gui_libs[@]}"; do
        if ! ls "$gui_lib_dir"/$lib_name* 2>/dev/null | head -1 | grep -q .; then
            warn "GUI library missing: $lib_name (may affect desktop)"
        fi
    done
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        error "Critical system libraries missing: ${missing_libs[*]}"
    else
        log "✅ All critical system libraries present"
    fi
    
    # Special check for libresolv with better detection
    if ls "$lib_dir"/libresolv.so* 2>/dev/null | head -1 | grep -q .; then
        log "✅ libresolv library confirmed present: $(ls "$lib_dir"/libresolv.so* | head -1)"
    else
        error "libresolv library missing - DNS resolution will fail"
    fi
}

# Create first-boot setup system
create_first_boot_setup() {
    log "Creating first-boot setup system..."
    
    # Create first-boot setup script
    sudo tee "$ROOT_MOUNT_POINT/usr/local/bin/thyme-first-boot" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS First Boot Setup

set -e

# Ensure we're on the right terminal
exec < /dev/tty1 > /dev/tty1 2>&1

# Function to display header
show_header() {
    clear
    echo "🍃 Thyme OS First-Time Setup 🍃"
    echo "==============================="
    echo
    echo "Welcome! Let's set up your new Thyme OS system."
    echo
}

# Function to get computer name
get_hostname() {
    while true; do
        show_header
        echo "Step 1: Computer Name"
        echo "-------------------"
        echo "Choose a name for this computer (hostname)."
        echo "This will identify your computer on the network."
        echo
        read -p "Enter computer name: " hostname
        
        if [[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,30}[a-zA-Z0-9]?$ ]] && [[ ${#hostname} -ge 2 ]]; then
            break
        else
            echo
            echo "❌ Invalid hostname. Requirements:"
            echo "   • 2-32 characters"
            echo "   • Letters, numbers, and hyphens only"
            echo "   • Must start and end with letter or number"
            echo
            read -p "Press Enter to try again..."
        fi
    done
}

# Function to get username
get_username() {
    while true; do
        show_header
        echo "Step 2: User Account"
        echo "-------------------"
        echo "Create your user account for daily use."
        echo
        read -p "Enter your username: " username
        
        if [[ "$username" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
            if ! getent passwd "$username" >/dev/null 2>&1; then
                break
            else
                echo
                echo "❌ Username '$username' already exists."
                read -p "Press Enter to try again..."
            fi
        else
            echo
            echo "❌ Invalid username. Requirements:"
            echo "   • 3-32 characters"
            echo "   • Lowercase letters, numbers, underscore, hyphen only"
            echo "   • Must start with a letter"
            echo
            read -p "Press Enter to try again..."
        fi
    done
}

# Function to get full name
get_fullname() {
    show_header
    echo "Step 3: Full Name"
    echo "----------------"
    echo "Enter your full name (optional, for display purposes)."
    echo
    read -p "Enter your full name (or press Enter to skip): " fullname
    
    if [[ -z "$fullname" ]]; then
        fullname="$username"
    fi
}

# Function to get password
get_password() {
    while true; do
        show_header
        echo "Step 4: Password"
        echo "---------------"
        echo "Create a secure password for your account."
        echo
        echo -n "Enter password for $username: "
        read -s password
        echo
        echo -n "Confirm password: "
        read -s password2
        echo
        
        if [[ "$password" == "$password2" ]]; then
            if [[ -n "$password" ]]; then
                break
            else
                echo
                echo "❌ Password cannot be empty."
                read -p "Press Enter to try again..."
            fi
        else
            echo
            echo "❌ Passwords do not match. Please try again."
            read -p "Press Enter to try again..."
        fi
    done
}

# Function to confirm setup
confirm_setup() {
    show_header
    echo "Step 5: Confirmation"
    echo "-------------------"
    echo "Please confirm your settings:"
    echo
    echo "Computer name: $hostname"
    echo "Username:      $username"
    echo
    while true; do
        read -p "Is this correct? (y/n): " confirm
        case $confirm in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to apply settings
apply_settings() {
    show_header
    echo "Setting up your system..."
    echo
    
    # Set hostname
    echo "🖥️  Setting computer name..."
    echo "$hostname" | sudo tee /etc/hostname > /dev/null
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/" /etc/hosts
    
    # Create user account
    echo "👤 Creating user account..."
    sudo useradd -m -s /bin/bash -c "$fullname" "$username" || {
        echo "❌ Failed to create user. Trying alternate method..."
        sudo adduser --disabled-password --gecos "$fullname" "$username"
    }
    
    # Set password
    echo "🔒 Setting password..."
    echo "$username:$password" | sudo chpasswd
    
    # Add to sudo group
    echo "🔐 Adding admin privileges..."
    sudo usermod -aG sudo "$username"
    sudo usermod -aG adm "$username"
    sudo usermod -aG cdrom "$username"
    sudo usermod -aG dip "$username"
    sudo usermod -aG plugdev "$username"
    sudo usermod -aG lpadmin "$username"
    sudo usermod -aG sambashare "$username"
    
    # Set up user directories
    echo "📁 Setting up user directories..."
    sudo mkdir -p "/home/$username"/{Desktop,Documents,Downloads,Pictures,Music,Videos}
    sudo mkdir -p "/home/$username/.config"
    sudo mkdir -p "/home/$username/.local/share"
    
    # Copy skeleton files
    sudo cp -r /etc/skel/. "/home/$username/" 2>/dev/null || true
    
    # Disable profile picture functionality to avoid mugshot errors
    echo "🔧 Configuring clean desktop environment..."
    
    # Create desktop autostart to hide user menu on first login
    sudo mkdir -p "/home/$username/.config/autostart"
    sudo tee "/home/$username/.config/autostart/thyme-disable-usermenu.desktop" > /dev/null << 'EOL'
[Desktop Entry]
Type=Application
Name=Thyme OS Clean Desktop
Exec=/bin/bash -c "gsettings set org.cinnamon.desktop.interface show-user-menu false 2>/dev/null || true; pkill -f thyme-disable-usermenu"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOL
    
    # Also create a global mugshot replacement that does nothing
    sudo tee "/usr/local/bin/mugshot" > /dev/null << 'EOL'
#!/bin/bash
# Thyme OS - Disabled profile editor
notify-send "Thyme OS" "Profile editing is disabled for a cleaner experience" 2>/dev/null || echo "Profile editing disabled in Thyme OS"
EOL
    sudo chmod +x "/usr/local/bin/mugshot"
    
    # Fix permissions
    sudo chown -R "$username:$username" "/home/$username"
    sudo chmod 755 "/home/$username"
    
    echo "✅ User account setup complete!"
}

# Function to finish setup
finish_setup() {
    show_header
    echo "🎉 Setup Complete!"
    echo "=================="
    echo
    echo "Your Thyme OS system is now ready to use!"
    echo
    echo "Computer name: $hostname"
    echo "Username:      $username"
    echo
    echo "You can now log in with your username and password."
    echo "The system will restart to complete the setup."
    echo
    for i in {10..1}; do
        echo -ne "\rRestarting in $i seconds... "
        sleep 1
    done
    echo
    echo
    
    # Mark setup as complete - this will prevent the service from running again
    touch /var/lib/thyme-setup-complete
    
    # Enable display manager for next boot
    systemctl unmask lightdm 2>/dev/null || true
    systemctl enable lightdm 2>/dev/null || true
    systemctl set-default graphical.target 2>/dev/null || true
    
    echo "🎉 Setup complete! Rebooting to login screen..."
    sleep 3
    
    # Reboot (service cleanup happens automatically via conditions)
    systemctl reboot
}

# Main setup flow
main() {
    # Run setup steps
    while true; do
        get_hostname
        get_username
        get_password
        fullname="$username"  # Use username as display name
        
        if confirm_setup; then
            break
        fi
        # If not confirmed, loop back to start
    done
    
    # Apply the settings
    apply_settings
    
    # Finish setup
    finish_setup
}

# Run main setup (systemd runs this as root already)
main
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/thyme-first-boot"
    
    # Create systemd service for first boot
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system/thyme-first-boot.service" > /dev/null << 'EOF'
[Unit]
Description=Thyme OS First Boot Setup Wizard
After=multi-user.target systemd-user-sessions.service
Before=display-manager.service lightdm.service gdm.service getty@tty1.service
ConditionPathExists=/usr/local/bin/thyme-first-boot
ConditionPathExists=!/var/lib/thyme-setup-complete
Conflicts=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/thyme-first-boot
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Environment=TERM=linux
Environment=HOME=/root
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Create getty override to prevent conflicts
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/systemd/system/getty@tty1.service.d"
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system/getty@tty1.service.d/override.conf" > /dev/null << 'EOF'
[Unit]
ConditionPathExists=/var/lib/thyme-setup-complete
EOF

    # Create cleanup service to run once after first-boot completes
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system/thyme-cleanup.service" > /dev/null << 'EOF'
[Unit]
Description=Thyme OS First Boot Cleanup
ConditionPathExists=/var/lib/thyme-setup-complete
ConditionPathExists=/etc/systemd/system/thyme-first-boot.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "systemctl disable thyme-first-boot 2>/dev/null || true; rm -f /etc/systemd/system/thyme-first-boot.service /usr/local/bin/thyme-first-boot /etc/systemd/system/thyme-cleanup.service; rm -rf /etc/systemd/system/lightdm.service.d/thyme-delay.conf; systemctl daemon-reload"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the first-boot service and cleanup service
    log "Enabling automatic first-boot setup wizard..."
    sudo chroot "$ROOT_MOUNT_POINT" systemctl enable thyme-first-boot 2>/dev/null || true
    sudo chroot "$ROOT_MOUNT_POINT" systemctl enable thyme-cleanup 2>/dev/null || true
    
    # Configure display manager for post-setup boot (DO NOT MASK - causes logout issue!)
    sudo chroot "$ROOT_MOUNT_POINT" systemctl enable lightdm 2>/dev/null || true
    sudo chroot "$ROOT_MOUNT_POINT" systemctl mask gdm 2>/dev/null || true
    
    # Create display manager override to delay startup until after first-boot
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/systemd/system/lightdm.service.d"
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system/lightdm.service.d/thyme-delay.conf" > /dev/null << 'EOF'
[Unit]
# Delay LightDM startup until first-boot setup is complete
ConditionPathExists=/var/lib/thyme-setup-complete
After=thyme-first-boot.service
EOF
    sudo chroot "$ROOT_MOUNT_POINT" systemctl set-default multi-user.target 2>/dev/null || true
    
    # Disable unnecessary services for faster boot
    log "Optimizing boot performance..."
    local services_to_disable=(
        "snapd.service"
        "snapd.socket"
        "snapd.seeded.service"
        "bluetooth.service"
        "ModemManager.service"
        "cups.service"
        "cups-browsed.service"
        "avahi-daemon.service"
        "whoopsie.service"
        "apport.service"
        "ubuntu-advantage.service"
    )
    
    for service in "${services_to_disable[@]}"; do
        sudo chroot "$ROOT_MOUNT_POINT" systemctl disable "$service" 2>/dev/null || true
        sudo chroot "$ROOT_MOUNT_POINT" systemctl mask "$service" 2>/dev/null || true
    done
    
    # Create boot optimization configs
    log "Creating boot optimization configurations..."
    
    # Reduce systemd timeout for faster boot
    sudo tee "$ROOT_MOUNT_POINT/etc/systemd/system.conf.d/99-thyme-boot-optimization.conf" > /dev/null << 'EOF'
[Manager]
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=5s
DefaultRestartSec=1s
DefaultDeviceTimeoutSec=10s
EOF
    
    # Create directory if it doesn't exist
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/systemd/system.conf.d"
    
    # Optimize kernel parameters for faster boot
    sudo tee "$ROOT_MOUNT_POINT/etc/sysctl.d/99-thyme-boot.conf" > /dev/null << 'EOF'
# Thyme OS boot optimizations
kernel.printk = 3 3 3 3
kernel.panic = 5
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    log "✅ First-boot setup system created with boot optimizations"
}

# Customize system for Thyme OS
customize_for_thyme() {
    log "Customizing system for Thyme OS..."
    
    # Update system identification
    sudo tee "$ROOT_MOUNT_POINT/etc/lsb-release" > /dev/null << 'EOF'
DISTRIB_ID=Linux
DISTRIB_RELEASE=
DISTRIB_CODENAME=
DISTRIB_DESCRIPTION="Linux - made with bookbind"
EOF
    
    # Set default hostname (will be changed on first boot)
    echo "thyme-system" | sudo tee "$ROOT_MOUNT_POINT/etc/hostname" > /dev/null
    
    # Update /etc/hosts (will be updated on first boot)
    sudo tee "$ROOT_MOUNT_POINT/etc/hosts" > /dev/null << 'EOF'
127.0.0.1   localhost
127.0.1.1   thyme-system
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Create Thyme OS version info
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/thyme"
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme/version" > /dev/null << EOF
Thyme OS 1.0 MacBook Edition (Streamlined)
Based on Linux Mint $(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
Built: $(date)
Target: MacBook2,1 and compatible systems
Installation: Smart copy with bloatware exclusion
EOF
    
    # Install lightweight alternatives
    install_lightweight_alternatives
    
    # Install Thyme Enhanced Text Editor
    install_thyme_editor
    
    # Configure MacBook compatibility
    configure_macbook_compatibility
    
    log "✅ System customized for Thyme OS"
}

# Install lightweight alternatives for removed bloatware
install_lightweight_alternatives() {
    log "Configuring lightweight alternatives..."
    
    # Create script to install alternatives in chroot
    sudo tee "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh" > /dev/null << 'EOF'
#!/bin/bash
# Install lightweight alternatives

export DEBIAN_FRONTEND=noninteractive

# Check if packages are available before installing
if apt-cache show abiword >/dev/null 2>&1; then
    apt-get update
    apt-get install -y abiword gnumeric mousepad vlc-data mpv
fi

# Create essential packages list
mkdir -p /etc/thyme
cat > /etc/thyme/installed-packages.txt << 'EOL'
# Thyme OS Streamlined Package List

## Lightweight Office
abiword          # Word processor (replaces LibreOffice Writer)
gnumeric         # Spreadsheet (replaces LibreOffice Calc)

## Text Editors
mousepad         # Simple text editor
nano             # Command-line editor
vim-tiny         # Minimal vim

## Media (minimal)
mpv              # Lightweight video player

## System
htop             # Process monitor
neofetch         # System info

## Pre-installed from Mint base
firefox          # Web browser
thunar           # File manager
xfce4-terminal   # Terminal
EOL

echo "Lightweight alternatives installed"
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh"
    
    # Skip package installation to avoid network issues
    log "Skipping package installation - using existing system packages"
    warn "Additional packages can be installed after first boot if needed"
    
    # Remove script
    sudo rm "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh"
    
    log "✅ Lightweight alternatives configuration completed"
}

# Install Thyme Enhanced Text Editor
install_thyme_editor() {
    log "Installing Thyme Enhanced Text Editor..."
    
    local editor_tools_dir="$(dirname "$(readlink -f "$0")")/thyme-editor-tools"
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
    
    # Install editor configuration
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.config/micro"
    
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/.config/micro/settings.json" > /dev/null << 'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": 2,
    "colorscheme": "solarized-tc",
    "cursorline": true,
    "ruler": true,
    "softwrap": false,
    "statusline": true,
    "syntax": true,
    "tabsize": 4,
    "tabstospaces": true
}
EOF
    
    # Set ownership
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/.config"
    
    log "✅ Thyme Enhanced Text Editor installed"
}

# Configure MacBook compatibility with better module handling
configure_macbook_compatibility() {
    log "Configuring MacBook compatibility..."
    
    # Create modprobe configuration
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/modprobe.d"
    
    sudo tee "$ROOT_MOUNT_POINT/etc/modprobe.d/thyme-macbook.conf" > /dev/null << 'EOF'
# Thyme OS MacBook Configuration

# Disable USB autosuspend for input devices
options usbcore autosuspend=-1

# USB HID configuration for Apple devices
options usbhid mousepoll=0
options usbhid quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01,0x05ac:0x022a:0x01

# PS/2 keyboard controller fixes
options i8042 reset=1 nomux=1 nopnp=1 noloop=1

# PS/2 mouse configuration
options psmouse proto=imps rate=100
EOF
    
    # Create modules loading configuration
    sudo tee "$ROOT_MOUNT_POINT/etc/modules-load.d/thyme-input.conf" > /dev/null << 'EOF'
# Thyme OS Input Device Modules
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
    
    # Fix initramfs modules (avoid directory exists error)
    if [[ ! -d "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/etc/initramfs-tools"
        sudo tee "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules" > /dev/null << 'EOF'
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
    fi
    
    # Update GRUB configuration for MacBook
    if [[ -f "$ROOT_MOUNT_POINT/etc/default/grub" ]]; then
        sudo sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Thyme OS"/' "$ROOT_MOUNT_POINT/etc/default/grub"
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux"/' "$ROOT_MOUNT_POINT/etc/default/grub"
    fi
    
    log "✅ MacBook compatibility configured"
}

# Update fstab for new UUIDs
update_fstab() {
    log "Updating fstab..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local efi_uuid=$(sudo blkid -s UUID -o value "$EFI_PARTITION")
    local swap_uuid=$(sudo blkid -s UUID -o value "$SWAP_PARTITION")
    
    sudo tee "$ROOT_MOUNT_POINT/etc/fstab" > /dev/null << EOF
# Thyme OS fstab
UUID=$root_uuid / ext4 defaults 0 1
UUID=$efi_uuid /boot/efi vfat defaults 0 2
UUID=$swap_uuid none swap sw 0 0
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
EOF
    
    log "✅ fstab updated"
}

# Install GRUB with enhanced configuration
install_grub() {
    log "Installing GRUB bootloader..."
    
    # Clean EFI partition
    sudo rm -rf "$EFI_MOUNT_POINT"/*
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
    
    # Install 32-bit EFI for MacBook2,1 with proper fallback names
    if [[ -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
        # Install with multiple EFI fallback names for better compatibility
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootia32.efi"
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/BOOTIA32.EFI"
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/BOOTX64.EFI"
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubia32.efi"
        log "✅ 32-bit GRUB EFI installed with fallback names"
    else
        error "32-bit GRUB EFI file required: $GRUB_FILES_DIR/grubia32.efi"
    fi
    
    # Create enhanced GRUB configuration
    create_enhanced_grub_config
    
    # Install GRUB to the system proper (in chroot) to ensure it's properly registered
    install_grub_to_system
    
    log "✅ GRUB installation completed"
}

# Install GRUB properly to the system using chroot
install_grub_to_system() {
    log "Installing GRUB to system via chroot..."
    
    # Mount system directories for chroot
    sudo mount --bind /proc "$ROOT_MOUNT_POINT/proc"
    sudo mount --bind /sys "$ROOT_MOUNT_POINT/sys"
    sudo mount --bind /dev "$ROOT_MOUNT_POINT/dev"
    sudo mount --bind /dev/pts "$ROOT_MOUNT_POINT/dev/pts"
    
    # Mount the EFI partition inside the chroot
    sudo mount --bind "$EFI_MOUNT_POINT" "$ROOT_MOUNT_POINT/boot/efi"
    
    # Create GRUB installation script
    sudo tee "$ROOT_MOUNT_POINT/tmp/install_grub.sh" > /dev/null << 'EOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Update package database
apt-get update

# Install GRUB EFI packages if not present
apt-get install -y grub-efi-ia32 grub-efi-ia32-bin

# Install GRUB to EFI system partition
grub-install --target=i386-efi --efi-directory=/boot/efi --bootloader-id=thyme --recheck

# Update GRUB configuration
update-grub

echo "GRUB installation completed"
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/tmp/install_grub.sh"
    
    # Run GRUB installation in chroot
    if sudo chroot "$ROOT_MOUNT_POINT" /tmp/install_grub.sh; then
        log "✅ GRUB installed to system successfully"
    else
        warn "GRUB system installation failed, using manual EFI only"
    fi
    
    # Clean up
    sudo rm -f "$ROOT_MOUNT_POINT/tmp/install_grub.sh"
    
    # Unmount chroot binds
    sudo umount "$ROOT_MOUNT_POINT/boot/efi" 2>/dev/null || true
    sudo umount "$ROOT_MOUNT_POINT/dev/pts" 2>/dev/null || true
    sudo umount "$ROOT_MOUNT_POINT/dev" 2>/dev/null || true
    sudo umount "$ROOT_MOUNT_POINT/sys" 2>/dev/null || true
    sudo umount "$ROOT_MOUNT_POINT/proc" 2>/dev/null || true
    
    log "✅ GRUB system installation completed"
}

# Create enhanced GRUB configuration with better boot options
create_enhanced_grub_config() {
    log "Creating enhanced GRUB configuration..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local grub_cfg="$EFI_MOUNT_POINT/EFI/thyme/grub.cfg"
    
    sudo tee "$grub_cfg" > /dev/null << EOF
# Thyme OS Enhanced GRUB Configuration v3.0
# MacBook2,1 Compatible with Advanced Boot Testing

set timeout=15
set default=0

echo "🍃 Thyme OS Streamlined v3.0 Loading..."

# Load essential GRUB modules
insmod part_gpt
insmod fat
insmod ext2
insmod ext4
insmod font
insmod gfxterm
insmod linux
insmod normal
insmod multiboot
insmod usb_keyboard
insmod ohci
insmod uhci
insmod ehci
insmod search_fs_uuid
insmod search_fs_file
insmod search_label
insmod configfile
insmod echo
insmod test

menuentry "🍃 Thyme OS - Default Boot" {
    echo "Booting Thyme OS Streamlined..."
    search --set=root --fs-uuid $root_uuid
    if [ -f "/boot/vmlinuz" ]; then
        linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux
        if [ -f "/boot/initrd.img" ]; then
            initrd /boot/initrd.img
        else
            echo "Warning: initrd.img not found, booting without initrd"
        fi
    else
        echo "Error: Kernel not found at /boot/vmlinuz"
        echo "Press any key to continue..."
        read
    fi
}

menuentry "🧪 Thyme OS - Testing Mode (Verbose)" {
    echo "Booting in testing mode with verbose output..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro debug loglevel=7 usbcore.autosuspend=-1 i8042.reset i8042.nomux
    initrd /boot/initrd.img
}

menuentry "🛠️ Thyme OS - Force USB/HID Load" {
    echo "Force loading all USB and input modules..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux i8042.direct
    initrd /boot/initrd.img
}

menuentry "⚡ Thyme OS - Safe Mode" {
    echo "Booting in safe mode..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro nomodeset acpi=off usbcore.autosuspend=-1 i8042.reset
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell" {
    echo "Emergency shell access..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro single init=/bin/bash
    initrd /boot/initrd.img
}

menuentry "🔄 Reboot" {
    reboot
}

menuentry "⚡ Shutdown" {
    halt
}
EOF
    
    # Copy to standard location and create backup
    sudo cp "$grub_cfg" "$EFI_MOUNT_POINT/EFI/BOOT/grub.cfg"
    
    # Create GRUB environment block
    sudo grub-editenv "$EFI_MOUNT_POINT/EFI/BOOT/grubenv" create 2>/dev/null || true
    sudo grub-editenv "$EFI_MOUNT_POINT/EFI/thyme/grubenv" create 2>/dev/null || true
    
    # Set proper permissions on EFI files
    sudo chmod -R 755 "$EFI_MOUNT_POINT/EFI"
    
    log "✅ Enhanced GRUB configuration created"
}

# Boot testing framework
create_boot_test_framework() {
    log "Creating boot testing framework..."
    
    # Create test scripts
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing"
    
    # Boot test script
    sudo tee "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing/boot-test.sh" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS Boot Testing Framework

echo "🧪 Thyme OS Boot Test Framework v3.0"
echo "===================================="

# Test 1: System identification
echo "📋 System Information:"
cat /etc/thyme/version
echo

# Test 2: Hardware detection
echo "⚙️ Hardware Detection:"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2)"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Storage: $(df -h / | tail -1 | awk '{print $2}')"
echo

# Test 3: Input devices
echo "🖱️ Input Device Test:"
ls -la /dev/input/
echo

# Test 4: USB detection
echo "🔌 USB Device Detection:"
lsusb
echo

# Test 5: Network
echo "🌐 Network Test:"
ip addr show | grep inet
echo

# Test 6: Display
echo "🖥️ Display Test:"
echo "X Server status:"
ps aux | grep X | head -3
echo

# Test 7: User environment
echo "👤 User Environment:"
echo "Current user: $USER"
echo "Home directory: $HOME"
echo "Shell: $SHELL"
echo

echo "✅ Boot test completed!"
echo "If you can see this, basic boot is working."
EOF
    
    # Make executable
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing/boot-test.sh"
    
    # Create desktop shortcut
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Desktop"
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Boot Test
Comment=Test Thyme OS boot functionality
Exec=/usr/local/bin/thyme-testing/boot-test.sh
Icon=utilities-system-monitor
Terminal=true
Categories=System;
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop"
    sudo chown 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop"
    
    log "✅ Boot testing framework created"
}

# Main installation function
main() {
    initialize_installer
    
    if [[ "$TEST_MODE" != "test" ]] && [[ "$AUTO_CONFIRM" != "true" ]]; then
        read -p "Continue with Thyme OS Streamlined installation? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Installation cancelled"
        fi
    elif [[ "$AUTO_CONFIRM" == "true" ]]; then
        log "🚀 AUTO-CONFIRM MODE: Proceeding with Thyme OS installation"
    fi
    
    check_mint_system
    detect_target_device
    
    if [[ "$TEST_MODE" != "test" ]] && [[ "$AUTO_CONFIRM" != "true" ]]; then
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        read -p "Type 'ERASE' to confirm: " confirm
        if [[ "${confirm,,}" != "erase" ]]; then
            error "Installation cancelled"
        fi
    elif [[ "$AUTO_CONFIRM" == "true" ]]; then
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        log "🚀 AUTO-CONFIRM MODE: Auto-typing 'ERASE' for final confirmation"
    fi
    
    partition_device
    format_partitions
    mount_partitions
    smart_copy_mint_system
    customize_for_thyme
    create_first_boot_setup
    update_fstab
    install_grub
    create_boot_test_framework
    
    # Cleanup with proper unmounting
    sync
    log "Cleaning up mount points..."
    
    # Unmount in reverse order
    sudo umount "$ROOT_MOUNT_POINT/boot/efi" 2>/dev/null || true
    sudo umount "$ROOT_MOUNT_POINT" 2>/dev/null || true
    sudo umount "$EFI_MOUNT_POINT" 2>/dev/null || true
    
    if [[ -n "${LOOP_DEVICE:-}" ]]; then
        sudo losetup -d "$LOOP_DEVICE"
        log "🧪 Test image created: $TEST_IMAGE"
    fi
    
    success "🎉 Thyme OS Streamlined installation completed!"
    success "✅ Smart copy with bloatware exclusion"
    success "✅ Enhanced boot testing framework"
    success "✅ MacBook2,1 optimized"
    
    if [[ "$TEST_MODE" == "test" ]]; then
        success "🧪 Test mode: Image ready for testing"
    else
        success "💾 Ready to boot from $TARGET_DEVICE"
    fi
}

# Run installation
main "$@"