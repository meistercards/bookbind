#!/bin/bash
# Thyme OS SSD Installer
# Installs Thyme OS with GRUB bootloader to SSD for MacBook compatibility
# Optimized for MacBook2,1 and similar vintage Macs

set -e

SCRIPT_VERSION="1.0"
INSTALL_LOG="/tmp/thyme_install.log"
GRUB_FILES_DIR="/home/meister/mintbook/grub_files"
WORK_DIR="/tmp/thyme_installer_work"

# Auto-install mode for testing (set to false for release)
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

info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

# Cleanup function
cleanup_on_error() {
    # Prevent recursive cleanup calls
    if [[ "${CLEANUP_IN_PROGRESS:-}" == "true" ]]; then
        echo "Cleanup already in progress, exiting..."
        exit 1
    fi
    export CLEANUP_IN_PROGRESS=true
    
    echo "Cleaning up after error..."
    
    # Unmount any mounted filesystems
    if [[ -n "$ROOT_MOUNT_POINT" ]] && mountpoint -q "$ROOT_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$ROOT_MOUNT_POINT" 2>/dev/null || true
        echo "Root partition unmounted"
    fi
    
    if [[ -n "$EFI_MOUNT_POINT" ]] && mountpoint -q "$EFI_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$EFI_MOUNT_POINT" 2>/dev/null || true
        echo "EFI partition unmounted"
    fi
    
    # Remove work directory
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
        echo "Work directory removed"
    fi
    
    echo "Cleanup completed"
    export CLEANUP_IN_PROGRESS=false
}

# Trap for cleanup - prevent infinite loops
trap 'echo "Installation interrupted. Cleaning up..."; cleanup_on_error; exit 1' INT TERM

# Initialize installer
initialize_installer() {
    echo -e "${PURPLE}"
    cat << 'EOF'
🍃 Thyme OS SSD Installer 🍃
============================

Installing Thyme OS to SSD with GRUB bootloader
Optimized for MacBook2,1 and vintage Mac hardware

⚠️  IMPORTANT WARNINGS:
━━━━━━━━━━━━━━━━━━━━━━━━
• This will ERASE the target SSD completely
• Make sure you have backups of important data
• Requires sudo privileges for disk operations
• Designed for MacBooks with EFI boot support

EOF
    echo -e "${NC}"
    
    # Create work directory
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Initialize log
    echo "Thyme OS SSD Installer Log - $(date)" > "$INSTALL_LOG"
    log "Installer initialized"
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this installer as root. It will request sudo when needed."
    fi
    
    # Check required commands
    local required_commands=("lsblk" "parted" "mkfs.ext4" "mkfs.fat" "mount" "grub-install" "grub-mkconfig")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Install: sudo apt install grub-efi-amd64 parted"
        fi
    done
    
    # Check for GRUB EFI files
    if [[ ! -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
        error "GRUB 32-bit EFI file not found: $GRUB_FILES_DIR/grubia32.efi"
    fi
    
    if [[ ! -f "$GRUB_FILES_DIR/grubx64.efi" ]]; then
        warn "GRUB 64-bit EFI file not found: $GRUB_FILES_DIR/grubx64.efi (32-bit should be sufficient)"
    fi
    
    # Check available space
    local available_space=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $available_space -lt 2 ]]; then
        error "Need at least 2GB free space in /tmp. Available: ${available_space}GB"
    fi
    
    log "✅ System requirements met"
}

# Detect and select target device
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
    
    # Find disks that are not the system disk
    while read -r device; do
        if [[ "$device" != "$system_disk" ]] && [[ -b "$device" ]]; then
            candidate_devices+=("$device")
        fi
    done < <(lsblk -d -n -o NAME | sed 's|^|/dev/|')
    
    if [[ ${#candidate_devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="${candidate_devices[0]}"
        log "Auto-detected target device: $TARGET_DEVICE"
        
        # Show device info
        local device_info=$(lsblk -o NAME,SIZE,TYPE,MODEL "$TARGET_DEVICE" 2>/dev/null | tail -n +2)
        echo "Target device details:"
        echo "$device_info"
        echo
        
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
            log "🚀 AUTO-INSTALL MODE: Auto-confirming $TARGET_DEVICE"
            confirm="y"
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
    
    log "✅ Target device selected: $TARGET_DEVICE"
    export TARGET_DEVICE
}

# Partition the target device
partition_device() {
    log "Partitioning device $TARGET_DEVICE..."
    
    # Unmount any mounted partitions from target device
    for partition in $(lsblk -ln -o NAME "$TARGET_DEVICE" | tail -n +2); do
        sudo umount "/dev/$partition" 2>/dev/null || true
    done
    
    # Create GPT partition table
    log "Creating GPT partition table..."
    sudo parted "$TARGET_DEVICE" --script mklabel gpt
    
    # Detect system RAM to determine swap size
    local system_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size_gb=10
    
    if [[ $system_ram_gb -ge 8 ]]; then
        swap_size_gb=4
        log "High RAM system detected (${system_ram_gb}GB) - creating 4GB swap"
    else
        swap_size_gb=10
        log "Low/Medium RAM system detected (${system_ram_gb}GB) - creating 10GB swap for performance"
    fi
    
    # Calculate partition boundaries
    local efi_start="1MiB"
    local efi_end="513MiB"
    local swap_start="513MiB"
    local swap_end="$((513 + swap_size_gb * 1024))MiB"
    local root_start="${swap_end}"
    local root_end="100%"
    
    # Create EFI System Partition (512MB)
    log "Creating EFI System Partition (512MB)..."
    sudo parted "$TARGET_DEVICE" --script mkpart ESP fat32 "$efi_start" "$efi_end"
    sudo parted "$TARGET_DEVICE" --script set 1 esp on
    
    # Create swap partition
    log "Creating swap partition (${swap_size_gb}GB)..."
    sudo parted "$TARGET_DEVICE" --script mkpart primary linux-swap "$swap_start" "$swap_end"
    
    # Create root partition (remaining space)
    log "Creating root partition..."
    sudo parted "$TARGET_DEVICE" --script mkpart primary ext4 "$root_start" "$root_end"
    
    # Wait for kernel to recognize partitions
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
    log "EFI Partition: $EFI_PARTITION"
    log "Swap Partition: $SWAP_PARTITION (${swap_size_gb}GB)"
    log "Root Partition: $ROOT_PARTITION"
    
    export EFI_PARTITION SWAP_PARTITION ROOT_PARTITION
}

# Format partitions
format_partitions() {
    log "Formatting partitions..."
    
    # Format EFI System Partition
    log "Formatting EFI partition as FAT32..."
    sudo mkfs.fat -F 32 -n "THYME_EFI" "$EFI_PARTITION"
    
    # Format swap partition
    log "Formatting swap partition..."
    sudo mkswap -L "ThymeSwap" "$SWAP_PARTITION"
    
    # Format root partition
    log "Formatting root partition as ext4..."
    sudo mkfs.ext4 -L "ThymeOS" "$ROOT_PARTITION"
    
    log "✅ Partitions formatted successfully"
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    # Create mount points
    ROOT_MOUNT_POINT="$WORK_DIR/root"
    EFI_MOUNT_POINT="$WORK_DIR/efi"
    
    mkdir -p "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    # Mount root partition
    sudo mount "$ROOT_PARTITION" "$ROOT_MOUNT_POINT"
    
    # Mount EFI partition
    sudo mount "$EFI_PARTITION" "$EFI_MOUNT_POINT"
    
    log "✅ Partitions mounted"
    log "Root: $ROOT_MOUNT_POINT"
    log "EFI: $EFI_MOUNT_POINT"
    
    export ROOT_MOUNT_POINT EFI_MOUNT_POINT
}

# Install base system
install_base_system() {
    log "Installing Thyme OS base system..."
    
    # Create basic directory structure
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var}
    sudo mkdir -p "$ROOT_MOUNT_POINT"/usr/{bin,lib,lib64,local,sbin,share}
    sudo mkdir -p "$ROOT_MOUNT_POINT"/var/{cache,lib,lock,log,mail,opt,run,spool,tmp}
    sudo mkdir -p "$ROOT_MOUNT_POINT"/etc/{apt,network,systemd}
    
    # Create essential configuration files
    log "Creating essential configuration files..."
    
    # /etc/fstab
    sudo tee "$ROOT_MOUNT_POINT/etc/fstab" > /dev/null << EOF
# Thyme OS fstab - MacBook optimized
UUID=$(sudo blkid -s UUID -o value "$ROOT_PARTITION") / ext4 defaults 0 1
UUID=$(sudo blkid -s UUID -o value "$EFI_PARTITION") /boot/efi vfat defaults 0 2
UUID=$(sudo blkid -s UUID -o value "$SWAP_PARTITION") none swap sw 0 0
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
EOF
    
    # /etc/hostname
    echo "thymeos" | sudo tee "$ROOT_MOUNT_POINT/etc/hostname" > /dev/null
    
    # /etc/hosts
    sudo tee "$ROOT_MOUNT_POINT/etc/hosts" > /dev/null << 'EOF'
127.0.0.1   localhost
127.0.1.1   thymeos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Basic /etc/passwd
    sudo tee "$ROOT_MOUNT_POINT/etc/passwd" > /dev/null << 'EOF'
root:x:0:0:root:/root:/bin/bash
thyme:x:1000:1000:Thyme User:/home/thyme:/bin/bash
EOF
    
    # Basic /etc/group
    sudo tee "$ROOT_MOUNT_POINT/etc/group" > /dev/null << 'EOF'
root:x:0:
thyme:x:1000:
sudo:x:27:thyme
EOF

    # Create global environment file to fix PATH issues
    sudo tee "$ROOT_MOUNT_POINT/etc/environment" > /dev/null << 'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SHELL="/bin/bash"
EOF

    # Create profile.d script for PATH fixes
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/profile.d"
    sudo tee "$ROOT_MOUNT_POINT/etc/profile.d/00-thyme-path.sh" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS PATH fixes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export SHELL="/bin/bash"
EOF
    sudo chmod +x "$ROOT_MOUNT_POINT/etc/profile.d/00-thyme-path.sh"
    
    # Create home directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme"
    sudo chown 1000:1000 "$ROOT_MOUNT_POINT/home/thyme"
    
    # Create boot directory structure
    sudo mkdir -p "$ROOT_MOUNT_POINT/boot/efi"
    
    # Copy essential binaries from host system
    log "Installing essential system binaries..."
    
    # Copy critical system binaries
    local essential_bins=(
        "/bin/bash"
        "/bin/sh" 
        "/bin/ls"
        "/bin/cat"
        "/bin/echo"
        "/bin/mount"
        "/bin/umount"
        "/bin/ps"
        "/bin/free"
        "/bin/df"
        "/bin/sleep"
        "/bin/mkdir"
        "/bin/chmod"
        "/bin/touch"
        "/bin/cp"
        "/bin/mv"
        "/bin/rm"
        "/bin/ln"
        "/bin/stty"
        "/bin/kbd_mode"
        "/usr/bin/id"
        "/usr/bin/tty"
        "/usr/bin/expr"
        "/usr/bin/hostname"
        "/usr/bin/mcookie"
        "/usr/bin/test"
        "/usr/bin/which"
        "/usr/bin/dirname"
        "/usr/bin/basename"
        "/usr/bin/mkdir"
        "/usr/bin/chmod"
        "/usr/bin/touch"
        "/usr/bin/loadkeys"
        "/usr/bin/dumpkeys"
        "/usr/bin/setkeycodes"
        "/usr/bin/kbd_mode"
        "/usr/bin/setleds"
        "/usr/bin/setfont"
        "/usr/bin/nproc"
        "/usr/bin/uname"
        "/usr/bin/date"
        "/usr/bin/head"
        "/usr/bin/tail"
        "/usr/bin/grep"
        "/usr/bin/awk"
        "/usr/bin/wc"
        "/usr/bin/tr"
        "/usr/bin/cut"
        "/usr/bin/sort"
        "/usr/bin/uniq"
        "/bin/date"
        "/bin/grep"
        "/sbin/init"
        "/sbin/modprobe"
        "/sbin/insmod"
        "/sbin/lsmod"
        "/sbin/rmmod"
        "/sbin/swapon"
        "/sbin/swapoff"
        "/sbin/halt"
        "/sbin/reboot"
        "/sbin/shutdown"
        "/sbin/mknod"
    )
    
    for bin in "${essential_bins[@]}"; do
        if [[ -f "$bin" ]]; then
            local dest_dir="$ROOT_MOUNT_POINT$(dirname "$bin")"
            sudo mkdir -p "$dest_dir"
            sudo cp "$bin" "$dest_dir/"
            log "Copied: $bin"
        fi
    done
    
    # Copy essential libraries more comprehensively
    log "Copying essential libraries and dependencies..."
    
    # Create library directories
    sudo mkdir -p "$ROOT_MOUNT_POINT/lib/x86_64-linux-gnu"
    sudo mkdir -p "$ROOT_MOUNT_POINT/lib64"
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/lib/x86_64-linux-gnu"
    
    # Copy all essential shared libraries
    log "Copying core system libraries..."
    for lib_dir in "/lib/x86_64-linux-gnu" "/usr/lib/x86_64-linux-gnu" "/lib64"; do
        if [[ -d "$lib_dir" ]]; then
            sudo cp -r "$lib_dir"/* "$ROOT_MOUNT_POINT$lib_dir/" 2>/dev/null || true
        fi
    done
    
    # Copy systemd libraries specifically
    if [[ -d "/usr/lib/systemd" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/lib"
        sudo cp -r "/usr/lib/systemd" "$ROOT_MOUNT_POINT/usr/lib/" 2>/dev/null || true
        log "Systemd libraries copied"
    fi
    
    # Always create a simple, reliable init script for MacBook compatibility
    log "Creating Thyme OS custom init script (systemd-free)..."
    sudo tee "$ROOT_MOUNT_POINT/sbin/init" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS Simple Init - No systemd dependencies
# Designed for MacBook2,1 compatibility

# Fix PATH immediately
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

# Create essential directories with proper paths
/usr/bin/mkdir -p /var/log 2>/dev/null || /bin/mkdir -p /var/log
/usr/bin/chmod 755 /var/log 2>/dev/null || /bin/chmod 755 /var/log

# Initialize keyboard and console
echo "Setting up keyboard and console..."

# Load keyboard modules
modprobe usbhid 2>/dev/null || true
modprobe hid 2>/dev/null || true
modprobe i8042 2>/dev/null || true
modprobe atkbd 2>/dev/null || true

# Set keyboard mode to Unicode
kbd_mode -u 2>/dev/null || true

# Load US keyboard layout
loadkeys us 2>/dev/null || true

# Set console font and keyboard
if [ -f /usr/share/consolefonts/Lat15-Fixed16.psf.gz ]; then
    setfont /usr/share/consolefonts/Lat15-Fixed16.psf.gz 2>/dev/null || true
fi

# Initialize terminal settings
stty sane 2>/dev/null || true
stty echo 2>/dev/null || true

# Run Thyme OS startup script
if [ -x /etc/thyme-startup.sh ]; then
    echo "Running Thyme OS hardware detection..."
    /etc/thyme-startup.sh
fi

echo ""
echo "🍃 Thyme OS Boot Test - $(date 2>/dev/null || echo 'Boot Complete')"
echo "======================================"
echo "System successfully booted from SSD!"
echo "Kernel: $(uname -r 2>/dev/null || echo 'Unknown')"
echo "Architecture: $(uname -m 2>/dev/null || echo 'Unknown')" 
echo "CPU Cores: $(nproc 2>/dev/null || echo 'Unknown')"

if command -v free >/dev/null 2>&1; then
    echo "Memory: $(free -h 2>/dev/null | grep Mem || echo 'Memory info unavailable')"
fi

if command -v df >/dev/null 2>&1; then
    echo "Storage: $(df -h / 2>/dev/null || echo 'Storage info unavailable')"
fi

# Show swap status
if command -v swapon >/dev/null 2>&1; then
    echo "Swap: $(swapon --show 2>/dev/null || echo 'No swap active')"
fi

echo ""
echo "🍃 Thyme OS is ready! This is a minimal test system."
echo "🔧 Hardware report available: cat /tmp/thyme-hardware-info"
echo "💡 Commands available: ls, ps, free, df, cat, mount"
echo ""
echo "🚀 Auto-starting desktop/shell in 3 seconds..."
sleep 3 2>/dev/null || echo "Starting shell immediately..."

# Start desktop or shell based on what's available (with better fallbacks)
if [ -x /usr/local/bin/start-desktop ]; then
    echo "🖥️ Starting XFCE Desktop Environment..."
    exec /usr/local/bin/start-desktop
elif [ -x /bin/bash ]; then
    echo "Starting bash shell..."
    export PS1='\u@thymeos:\w\$ '
    export HOME=/home/thyme
    cd /home/thyme 2>/dev/null || cd /
    exec /bin/bash --login
elif [ -x /bin/sh ]; then
    echo "Starting sh shell..."
    export PS1='thymeos$ '
    export HOME=/home/thyme
    cd /home/thyme 2>/dev/null || cd /
    exec /bin/sh
else
    echo "❌ No shell found! Attempting emergency recovery..."
    echo "Available executables in /bin:"
    ls /bin/ 2>/dev/null || echo "Cannot list /bin contents"
    echo "Available executables in /usr/bin:"
    ls /usr/bin/ 2>/dev/null || echo "Cannot list /usr/bin contents"
    echo ""
    echo "⚠️ System will halt in 10 seconds. Press Ctrl+Alt+Del to reboot."
    sleep 10 2>/dev/null || true
    halt 2>/dev/null || poweroff 2>/dev/null || echo "Cannot halt system"
fi
EOF
    sudo chmod +x "$ROOT_MOUNT_POINT/sbin/init"
    
    # Create a systemd compatibility symlink if someone wants to try systemd later
    if [[ -f "/sbin/init" ]] && [[ -f "$ROOT_MOUNT_POINT/sbin/init" ]]; then
        sudo cp "/sbin/init" "$ROOT_MOUNT_POINT/sbin/systemd-init" 2>/dev/null || true
        log "Systemd init backed up as /sbin/systemd-init (optional)"
    fi
    
    # Make sure init is executable and has proper permissions
    sudo chmod +x "$ROOT_MOUNT_POINT/sbin/init"
    
    # Create device nodes that might be needed
    sudo mkdir -p "$ROOT_MOUNT_POINT/dev"
    if command -v mknod >/dev/null 2>&1; then
        sudo mknod "$ROOT_MOUNT_POINT/dev/null" c 1 3 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/zero" c 1 5 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/console" c 5 1 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/tty" c 5 0 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/tty0" c 4 0 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/tty1" c 4 1 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/random" c 1 8 2>/dev/null || true
        sudo mknod "$ROOT_MOUNT_POINT/dev/urandom" c 1 9 2>/dev/null || true
        log "Essential device nodes created"
    fi
    
    # Create additional critical directories
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{proc,sys,dev/pts,dev/shm}
    sudo chmod 755 "$ROOT_MOUNT_POINT"/{proc,sys,dev}
    sudo chmod 1777 "$ROOT_MOUNT_POINT/dev/shm"
    
    log "✅ Base system installed"
}

# Install Linux kernel and modules
install_kernel() {
    log "Installing Linux kernel..."
    
    # Find the latest kernel on the host system
    local latest_kernel=$(ls /boot/vmlinuz-* | sort -V | tail -n 1)
    local latest_initrd=$(ls /boot/initrd.img-* | sort -V | tail -n 1)
    local kernel_version=$(basename "$latest_kernel" | sed 's/vmlinuz-//')
    
    if [[ ! -f "$latest_kernel" ]] || [[ ! -f "$latest_initrd" ]]; then
        error "Could not find kernel files on host system"
    fi
    
    log "Found kernel: $kernel_version"
    log "Kernel file: $latest_kernel"
    log "Initrd file: $latest_initrd"
    
    # Copy kernel and initrd to the SSD
    log "Copying kernel files to SSD..."
    sudo cp "$latest_kernel" "$ROOT_MOUNT_POINT/boot/vmlinuz"
    sudo cp "$latest_initrd" "$ROOT_MOUNT_POINT/boot/initrd.img"
    
    # Also copy with version-specific names for reference
    sudo cp "$latest_kernel" "$ROOT_MOUNT_POINT/boot/vmlinuz-$kernel_version"
    sudo cp "$latest_initrd" "$ROOT_MOUNT_POINT/boot/initrd.img-$kernel_version"
    
    # Copy System.map if available
    if [[ -f "/boot/System.map-$kernel_version" ]]; then
        sudo cp "/boot/System.map-$kernel_version" "$ROOT_MOUNT_POINT/boot/"
        log "System.map copied"
    fi
    
    # Copy kernel config if available
    if [[ -f "/boot/config-$kernel_version" ]]; then
        sudo cp "/boot/config-$kernel_version" "$ROOT_MOUNT_POINT/boot/"
        log "Kernel config copied"
    fi
    
    # Copy kernel modules if available
    if [[ -d "/lib/modules/$kernel_version" ]]; then
        log "Copying kernel modules (this may take a moment)..."
        sudo mkdir -p "$ROOT_MOUNT_POINT/lib/modules"
        sudo cp -r "/lib/modules/$kernel_version" "$ROOT_MOUNT_POINT/lib/modules/"
        log "✅ Kernel modules copied"
    else
        warn "Kernel modules not found for $kernel_version"
    fi
    
    # Copy essential firmware files
    if [[ -d "/lib/firmware" ]]; then
        log "Copying essential firmware files..."
        sudo mkdir -p "$ROOT_MOUNT_POINT/lib"
        # Copy only essential firmware to save space (focus on network and graphics)
        sudo mkdir -p "$ROOT_MOUNT_POINT/lib/firmware"
        for fw_dir in intel iwlwifi rtl_nic amdgpu radeon nvidia; do
            if [[ -d "/lib/firmware/$fw_dir" ]]; then
                sudo cp -r "/lib/firmware/$fw_dir" "$ROOT_MOUNT_POINT/lib/firmware/" 2>/dev/null || true
            fi
        done
        log "✅ Essential firmware copied"
    fi
    
    # Copy keyboard data and console fonts for input support
    log "Installing keyboard and console support..."
    
    # Copy keyboard maps
    if [[ -d "/usr/share/keymaps" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/share"
        sudo cp -r "/usr/share/keymaps" "$ROOT_MOUNT_POINT/usr/share/" 2>/dev/null || true
        log "Keyboard maps copied"
    fi
    
    # Copy console fonts
    if [[ -d "/usr/share/consolefonts" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/share"
        sudo cp -r "/usr/share/consolefonts" "$ROOT_MOUNT_POINT/usr/share/" 2>/dev/null || true
        log "Console fonts copied"
    fi
    
    # Copy keyboard layout files (alternative location)
    if [[ -d "/usr/share/kbd" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/share"
        sudo cp -r "/usr/share/kbd" "$ROOT_MOUNT_POINT/usr/share/" 2>/dev/null || true
        log "Keyboard data files copied"
    fi
    
    # Create kernel info file
    sudo tee "$ROOT_MOUNT_POINT/boot/kernel-info.txt" > /dev/null << EOF
Thyme OS Kernel Information
==========================

Kernel Version: $kernel_version
Source System: $(uname -r)
Installation Date: $(date)
Architecture: $(uname -m)

Files installed:
- /boot/vmlinuz (kernel image)
- /boot/initrd.img (initial ramdisk)
- /lib/modules/$kernel_version/ (kernel modules)
- /lib/firmware/ (hardware firmware)

Boot Parameters:
- MacBook2,1 optimized
- Memory limit: 2GB (configurable in GRUB)
- Graphics: EFI GOP + legacy support
EOF
    
    log "✅ Kernel installation completed"
    log "Installed kernel: $kernel_version"
}

# Install desktop environment
install_desktop_environment() {
    case "$DESKTOP_ENV" in
        "xfce")
            install_xfce_desktop
            ;;
        "gnome")
            install_gnome_desktop
            ;;
        "minimal")
            log "Minimal system selected - skipping desktop installation"
            ;;
    esac
}

# Install XFCE desktop environment
install_xfce_desktop() {
    log "Installing XFCE desktop environment..."
    
    # Create basic X11 and desktop directories
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{etc/X11,usr/share/{applications,pixmaps,themes},home/thyme/{Desktop,.config}}
    
    # Copy essential X11 and desktop binaries
    log "Installing X11 and desktop binaries..."
    local desktop_bins=(
        "/usr/bin/startx"
        "/usr/bin/xinit"
        "/usr/bin/xauth"
        "/usr/bin/xhost"
        "/usr/bin/xset"
        "/usr/bin/xrandr"
        "/usr/bin/xdpyinfo"
        "/usr/bin/xfce4-session"
        "/usr/bin/xfce4-panel"
        "/usr/bin/xfdesktop"
        "/usr/bin/xfwm4"
        "/usr/bin/thunar"
        "/usr/bin/xfce4-terminal"
        "/usr/bin/xterm"
        "/usr/bin/firefox"
        "/usr/bin/X"
        "/usr/bin/Xorg"
        "/usr/bin/whoami"
        "/usr/bin/wc"
        "/usr/bin/tr"
        "/usr/bin/sort"
        "/usr/bin/uniq"
        "/usr/bin/head"
        "/usr/bin/tail"
        "/usr/bin/grep"
        "/usr/bin/awk"
        "/usr/bin/sed"
        "/usr/bin/cut"
        "/usr/bin/loadkeys"
        "/usr/bin/kbd_mode"
        "/usr/bin/setkeycodes"
        "/bin/dmesg"
        "/sbin/modprobe"
        "/sbin/lsmod"
    )
    
    for bin in "${desktop_bins[@]}"; do
        if [[ -f "$bin" ]]; then
            local dest_dir="$ROOT_MOUNT_POINT$(dirname "$bin")"
            sudo mkdir -p "$dest_dir"
            sudo cp "$bin" "$dest_dir/" 2>/dev/null || true
            log "Copied: $bin"
        fi
    done
    
    # Install XFCE via package extraction (since we don't have package manager yet)
    log "Installing XFCE packages from host system..."
    
    # Copy comprehensive X11 and XFCE libraries
    log "Copying X11 and XFCE libraries..."
    local xfce_lib_dirs=(
        "/usr/lib/x86_64-linux-gnu/xfce4"
        "/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0"
        "/usr/lib/x86_64-linux-gnu/gtk-3.0"
        "/usr/lib/x86_64-linux-gnu/pango"
        "/usr/lib/x86_64-linux-gnu/girepository-1.0"
        "/usr/share/xfce4"
        "/usr/share/themes"
        "/usr/share/icons"
        "/usr/share/pixmaps"
        "/usr/share/fonts"
        "/usr/share/applications"
    )
    
    for lib_dir in "${xfce_lib_dirs[@]}"; do
        if [[ -d "$lib_dir" ]]; then
            local dest_dir="$ROOT_MOUNT_POINT$lib_dir"
            sudo mkdir -p "$(dirname "$dest_dir")"
            sudo cp -r "$lib_dir" "$(dirname "$dest_dir")/" 2>/dev/null || true
            log "Copied XFCE libraries: $lib_dir"
        fi
    done
    
    # Copy XFCE configuration files
    if [[ -d "/etc/xdg/xfce4" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/etc/xdg"
        sudo cp -r "/etc/xdg/xfce4" "$ROOT_MOUNT_POINT/etc/xdg/" 2>/dev/null || true
    fi
    
    # Copy all X11 configuration and data
    if [[ -d "/usr/share/X11" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/share"
        sudo cp -r "/usr/share/X11" "$ROOT_MOUNT_POINT/usr/share/" 2>/dev/null || true
    fi
    
    # Create X11 configuration for offline operation
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/X11"
    sudo tee "$ROOT_MOUNT_POINT/etc/X11/xorg.conf" > /dev/null << 'EOF'
# Thyme OS X11 Configuration - Offline MacBook Compatible
Section "ServerLayout"
    Identifier     "ThymeLayout"
    Screen      0  "Screen0"
    Option         "DontVTSwitch" "false"
    Option         "DontZap" "false"
EndSection

Section "Files"
    ModulePath   "/usr/lib/xorg/modules"
    FontPath     "/usr/share/fonts/X11/misc"
    FontPath     "/usr/share/fonts/X11/100dpi/:unscaled"
    FontPath     "/usr/share/fonts/X11/75dpi/:unscaled"
    FontPath     "/usr/share/fonts/X11/Type1"
    FontPath     "/usr/share/fonts/X11/100dpi"
    FontPath     "/usr/share/fonts/X11/75dpi"
    FontPath     "/var/lib/defoma/x-ttcidfont-conf.d/dirs/TrueType"
EndSection

Section "Module"
    Load  "bitmap"
    Load  "ddc"
    Load  "dri"
    Load  "extmod"
    Load  "freetype"
    Load  "glx"
    Load  "int10"
    Load  "type1"
    Load  "vbe"
EndSection

Section "Monitor"
    Identifier   "Monitor0"
    VendorName   "Monitor Vendor"
    ModelName    "Monitor Model"
EndSection

Section "Device"
    Identifier  "Card0"
    Driver      "vesa"
    VendorName  "Unknown Vendor"
    BoardName   "Unknown Board"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device     "Card0"
    Monitor    "Monitor0"
    SubSection "Display"
        Viewport   0 0
        Depth     24
    EndSubSection
EndSection
EOF
    
    # Create X11 wrapper script that works offline
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin"
    sudo tee "$ROOT_MOUNT_POINT/usr/local/bin/startx-offline" > /dev/null << 'EOF'
#!/bin/bash
# Offline X11 startup script for Thyme OS
export DISPLAY=:0
export XAUTHORITY="$HOME/.Xauthority"

# Create log directory if it doesn't exist
mkdir -p /var/log

# Start X11 without network dependencies
exec /usr/bin/X :0 -config /etc/X11/xorg.conf -logfile /var/log/Xorg.0.log -auth "$XAUTHORITY" vt7
EOF
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/startx-offline"
    
    # Copy X11 libraries
    if [[ -d "/usr/lib/xorg" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/lib"
        sudo cp -r "/usr/lib/xorg" "$ROOT_MOUNT_POINT/usr/lib/" 2>/dev/null || true
    fi
    
    # Copy X11 modules and drivers
    if [[ -d "/usr/lib/x86_64-linux-gnu/xorg" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/usr/lib/x86_64-linux-gnu"
        sudo cp -r "/usr/lib/x86_64-linux-gnu/xorg" "$ROOT_MOUNT_POINT/usr/lib/x86_64-linux-gnu/" 2>/dev/null || true
    fi
    
    # Create basic XFCE session startup
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/.xinitrc" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS XFCE Session
export DESKTOP_SESSION=xfce
export XDG_CURRENT_DESKTOP=XFCE
exec startxfce4
EOF
    
    # Create auto-start desktop script
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin"
    sudo tee "$ROOT_MOUNT_POINT/usr/local/bin/start-desktop" > /dev/null << 'EOF'
#!/bin/bash
# Start XFCE Desktop automatically - Offline Compatible
echo "🍃 Starting Thyme OS Desktop (Offline Mode)..."

# Fix PATH to include all binary directories
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set up X11 environment for offline operation
export DISPLAY=:0
export XAUTHORITY="$HOME/.Xauthority"
export XDG_RUNTIME_DIR=/tmp/xdg-runtime-$(id -u)

# Use full paths for commands in case PATH is still broken
/usr/bin/mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || /bin/mkdir -p "$XDG_RUNTIME_DIR"
/usr/bin/chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || /bin/chmod 700 "$XDG_RUNTIME_DIR"

# Create log directory with proper permissions
/usr/bin/mkdir -p /var/log 2>/dev/null || /bin/mkdir -p /var/log
/usr/bin/chmod 755 /var/log 2>/dev/null || /bin/chmod 755 /var/log

# Create minimal .Xauthority if it doesn't exist
if [ ! -f "$XAUTHORITY" ]; then
    /usr/bin/touch "$XAUTHORITY" 2>/dev/null || /bin/touch "$XAUTHORITY"
    /usr/bin/chmod 600 "$XAUTHORITY" 2>/dev/null || /bin/chmod 600 "$XAUTHORITY"
fi

# Start X server in background using offline configuration
echo "Starting X server..."
/usr/bin/X :0 -config /etc/X11/xorg.conf -logfile /var/log/Xorg.0.log -auth "$XAUTHORITY" vt7 &
X_PID=$!

# Wait for X server to start
sleep 3

# Check if X server is running
if ! ps -p $X_PID > /dev/null 2>&1; then
    echo "❌ X server failed to start - falling back to terminal"
    exec /bin/bash
fi

# Start window manager
echo "Starting XFCE..."
if command -v xfce4-session >/dev/null 2>&1; then
    exec xfce4-session
elif command -v startxfce4 >/dev/null 2>&1; then
    exec startxfce4
else
    echo "❌ XFCE not available - starting basic X session"
    if command -v xterm >/dev/null 2>&1; then
        exec xterm
    else
        echo "❌ No X applications available - falling back to terminal"
        kill $X_PID 2>/dev/null
        exec /bin/bash
    fi
fi
EOF
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/start-desktop"
    
    # Set proper ownership
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme"
    
    log "✅ XFCE desktop environment installed"
}

# Install GNOME desktop environment  
install_gnome_desktop() {
    log "Installing GNOME desktop environment..."
    log "⚠️ GNOME installation not yet implemented - falling back to minimal"
}

# Choose EFI architecture
choose_efi_architecture() {
    log "Choosing EFI architecture for MacBook compatibility..."
    
    echo
    echo "🍃 EFI Architecture Selection"
    echo "============================="
    echo
    echo "MacBook models and recommended EFI architecture:"
    echo "• MacBook1,1 - MacBook4,1 (2006-2008): 32-bit EFI REQUIRED"
    echo "• MacBook5,1+ (2009+): 64-bit EFI preferred"
    echo "• MacBookPro1,1 - MacBookPro4,1: 32-bit EFI REQUIRED" 
    echo "• MacBookPro5,1+ (2009+): 64-bit EFI preferred"
    echo
    echo "Your target: MacBook2,1 → 32-bit EFI STRONGLY RECOMMENDED"
    echo
    echo "EFI Architecture Options:"
    echo "1. 32-bit EFI only (recommended for MacBook2,1)"
    echo "2. 64-bit EFI only"
    echo "3. Both 32-bit and 64-bit (install both, prioritize 32-bit)"
    echo
    
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        efi_choice="1"
        EFI_ARCH="32bit"
        log "🚀 AUTO-INSTALL MODE: Selected 32-bit EFI (MacBook2,1 optimal)"
    else
        while true; do
            read -p "Select EFI architecture (1-3): " efi_choice
            case "$efi_choice" in
                1)
                    EFI_ARCH="32bit"
                    log "Selected: 32-bit EFI only (MacBook2,1 compatible)"
                    break
                    ;;
                2)
                    EFI_ARCH="64bit"
                    warn "64-bit EFI selected - may not work on MacBook2,1"
                    read -p "Are you sure? This may prevent booting on older MacBooks (y/n): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        log "Selected: 64-bit EFI only"
                        break
                    fi
                    ;;
                3)
                    EFI_ARCH="both"
                    log "Selected: Both architectures (32-bit priority for compatibility)"
                    break
                    ;;
                *)
                    echo "Invalid selection. Please choose 1, 2, or 3."
                    ;;
            esac
        done
    fi
    
    export EFI_ARCH
}

# Choose desktop environment
choose_desktop_environment() {
    log "Choosing desktop environment..."
    
    echo
    echo "🍃 Desktop Environment Selection"
    echo "==============================="
    echo
    echo "Desktop Options:"
    echo "1. XFCE Desktop (recommended for MacBook2,1)"
    echo "2. Minimal Text-Only System (current test system)"
    echo "3. GNOME Desktop (requires 4GB+ RAM)"
    echo
    
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        desktop_choice="1"
        DESKTOP_ENV="xfce"
        log "🚀 AUTO-INSTALL MODE: Selected XFCE Desktop (MacBook-optimized)"
    else
        while true; do
            read -p "Select desktop environment (1-3): " desktop_choice
            case "$desktop_choice" in
                1)
                    DESKTOP_ENV="xfce"
                    log "Selected: XFCE Desktop (MacBook-optimized)"
                    break
                    ;;
                2)
                    DESKTOP_ENV="minimal"
                    log "Selected: Minimal text-only system"
                    break
                    ;;
                3)
                    DESKTOP_ENV="gnome"
                    warn "GNOME selected - requires significant RAM"
                    read -p "Continue with GNOME? (y/n): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        log "Selected: GNOME Desktop"
                        break
                    fi
                    ;;
                *)
                    echo "Invalid selection. Please choose 1, 2, or 3."
                    ;;
            esac
        done
    fi
    
    export DESKTOP_ENV
}

# Show installation plan summary
show_installation_plan() {
    echo
    echo -e "${BLUE}🍃 Thyme OS Installation Plan${NC}"
    echo "=============================="
    echo
    echo "Target Device: $TARGET_DEVICE"
    
    # Detect system RAM for swap display
    local system_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size_gb=10
    if [[ $system_ram_gb -ge 8 ]]; then
        swap_size_gb=4
    fi
    
    echo "Partition Layout:"
    echo "  1. EFI System Partition: 512MB (FAT32)"
    echo "  2. Swap Partition: ${swap_size_gb}GB (Linux Swap)"
    echo "  3. Root Partition: Remaining space (ext4)"
    echo
    echo "EFI Architecture: $EFI_ARCH"
    echo "Host System RAM: ${system_ram_gb}GB → ${swap_size_gb}GB swap"
    echo "Optimization: MacBook2,1 compatible (hardware-adaptive)"
    echo
    warn "This will COMPLETELY ERASE all data on $TARGET_DEVICE"
    echo
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        log "🚀 AUTO-INSTALL MODE: Auto-confirming installation plan"
        final_confirm="y"
    else
        read -p "Proceed with installation? (y/n): " final_confirm
        if [[ ! "$final_confirm" =~ ^[Yy]$ ]] && [[ "${final_confirm,,}" != "yes" ]]; then
            error "Installation cancelled by user"
        fi
    fi
    
    log "✅ Installation plan confirmed - proceeding..."
}

# Install GRUB bootloader
install_grub() {
    log "Installing GRUB bootloader..."
    
    # Create EFI directory structure
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
    
    # Copy GRUB EFI files based on user choice
    log "Installing GRUB EFI bootloaders for: $EFI_ARCH"
    
    case "$EFI_ARCH" in
        "32bit")
            # Clean up any existing EFI entries first
            log "Cleaning EFI partition for 32-bit only installation..."
            sudo rm -rf "$EFI_MOUNT_POINT/EFI"/*
            sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
            sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
            
            # NUCLEAR EFI cleanup to completely eliminate i386 conflicts
            log "Performing nuclear EFI cleanup to prevent i386 errors..."
            
            # Completely wipe and recreate EFI partition structure
            sudo umount "$EFI_MOUNT_POINT" 2>/dev/null || true
            sudo mkfs.fat -F 32 -n "THYME_EFI" "$EFI_PARTITION"
            sudo mount "$EFI_PARTITION" "$EFI_MOUNT_POINT"
            
            # Create only ThymeOS EFI structure - nothing else
            sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
            sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
            
            # Clean any existing EFI boot variables (requires EFI system)
            if command -v efibootmgr >/dev/null 2>&1; then
                log "Cleaning EFI boot variables..."
                # Get current boot order and remove all entries except EFI defaults
                efibootmgr 2>/dev/null | grep "^Boot" | while read -r line; do
                    bootnum=$(echo "$line" | awk '{print $1}' | sed 's/Boot//' | sed 's/\*//')
                    # Keep only EFI built-in entries (0000-0003 typically)
                    if [ "$bootnum" -gt 3 ] 2>/dev/null; then
                        sudo efibootmgr -B -b "$bootnum" 2>/dev/null || true
                    fi
                done
            fi
            
            # Install only 32-bit EFI - NO 64-bit files
            if [[ -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
                sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootia32.efi"
                sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubia32.efi"
                
                # Make sure no 64-bit bootloader exists anywhere
                sudo rm -f "$EFI_MOUNT_POINT/EFI/BOOT/bootx64.efi" 2>/dev/null || true
                sudo rm -f "$EFI_MOUNT_POINT/EFI/thyme/grubx64.efi" 2>/dev/null || true
                
                # Remove any other potential EFI bootloaders that might conflict
                sudo find "$EFI_MOUNT_POINT/EFI" -name "*.efi" ! -name "bootia32.efi" ! -name "grubia32.efi" -delete 2>/dev/null || true
                
                log "✅ 32-bit EFI bootloader installed ONLY (MacBook2,1 compatible)"
                log "✅ All other EFI files removed to prevent Ubuntu conflicts"
            else
                error "32-bit GRUB EFI file required: $GRUB_FILES_DIR/grubia32.efi"
            fi
            ;;
        "64bit")
            # Install only 64-bit EFI
            if [[ -f "$GRUB_FILES_DIR/grubx64.efi" ]]; then
                sudo cp "$GRUB_FILES_DIR/grubx64.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootx64.efi"
                sudo cp "$GRUB_FILES_DIR/grubx64.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubx64.efi"
                log "✅ 64-bit EFI bootloader installed"
            else
                error "64-bit GRUB EFI file required: $GRUB_FILES_DIR/grubx64.efi"
            fi
            ;;
        "both")
            # Install both, with 32-bit as primary
            if [[ -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
                sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootia32.efi"
                sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubia32.efi"
                log "✅ 32-bit EFI bootloader installed (primary)"
            else
                error "32-bit GRUB EFI file required for compatibility"
            fi
            
            if [[ -f "$GRUB_FILES_DIR/grubx64.efi" ]]; then
                sudo cp "$GRUB_FILES_DIR/grubx64.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootx64.efi"
                sudo cp "$GRUB_FILES_DIR/grubx64.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubx64.efi"
                log "✅ 64-bit EFI bootloader installed (secondary)"
            fi
            ;;
    esac
    
    # Create GRUB configuration
    create_grub_config
    
    log "✅ GRUB installation completed"
}

# Create GRUB configuration optimized for MacBook2,1
create_grub_config() {
    log "Creating GRUB configuration for MacBook2,1..."
    
    local grub_cfg="$EFI_MOUNT_POINT/EFI/thyme/grub.cfg"
    
    sudo tee "$grub_cfg" > /dev/null << 'EOF'
# Thyme OS GRUB Configuration
# Optimized for MacBook2,1 and vintage Mac hardware (32-bit EFI)
# Prevents Ubuntu EFI conflicts

set timeout=15
set default=0

# Disable any Ubuntu boot attempts
set GRUB_DISABLE_OS_PROBER=true

# Debug info for troubleshooting
echo "🍃 Thyme OS GRUB Loading (Ubuntu EFI disabled)..."
echo "Platform: ${grub_platform}"
echo "CPU: ${grub_cpu}"
echo "GRUB Architecture: 32-bit EFI"

# Load essential modules for MacBook compatibility
insmod part_gpt
insmod part_msdos
insmod fat
insmod ext2
insmod ext4
insmod font
insmod gfxterm
insmod efi_gop
insmod efi_uga

# Conservative graphics setup for MacBook displays - start with text mode
if [ "${grub_platform}" = "efi" ]; then
    echo "EFI platform detected - setting up graphics..."
    if loadfont unicode; then
        # Start conservative for compatibility
        set gfxmode=text
        set gfxpayload=text
        terminal_output console
        echo "Graphics mode: text (safe for MacBook2,1)"
    else
        echo "Unicode font not available - using text mode"
        set gfxmode=text
        set gfxpayload=text
    fi
else
    echo "Non-EFI platform - using text mode"
fi

# Load USB and input drivers
echo "Loading USB and input drivers..."
insmod usb_keyboard
insmod ohci
insmod uhci
insmod ehci

# Main boot menu - Default optimized for MacBook2,1 and vintage hardware
menuentry "🍃 Thyme OS - Default (MacBook optimized)" {
    set gfxpayload=text
    echo "Booting Thyme OS - MacBook2,1 Default Mode"
    echo "Optimized for vintage MacBook hardware"
    
    # Find root partition by UUID
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    echo "Loading kernel with MacBook-safe parameters..."
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro nomodeset acpi=off pci=noacpi noapic nowatchdog mem=2G usbhid.quirks=0x05ac:0x020b:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop quiet
    
    echo "Loading initrd..."
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Performance Mode (newer hardware)" {
    set gfxpayload=keep
    echo "Booting Thyme OS in Performance Mode..."
    echo "For MacBook5,1+ and modern hardware"
    
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    echo "Loading kernel with full features..."
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro quiet splash
    
    echo "Loading initrd..."
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Ultra Safe Mode (troubleshooting)" {
    set gfxpayload=text
    echo "Booting Thyme OS in Ultra Safe Mode..."
    echo "Maximum compatibility for problematic hardware"
    
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro single nomodeset acpi=off pci=noacpi noapic nosmp maxcpus=1 nowatchdog no_timer_check mem=1536M init=/bin/bash
    initrd /boot/initrd.img
}

menuentry "🔍 Debug Mode - Verbose Boot (black screen fix)" {
    set gfxpayload=text
    echo "Booting with maximum debugging output..."
    echo "This will show all boot messages to help diagnose issues"
    
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    echo "Loading kernel with debug parameters..."
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro nomodeset acpi=off pci=noacpi noapic nowatchdog debug earlyprintk=vga,keep loglevel=8 ignore_loglevel usbhid.quirks=0x05ac:0x020b:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop
    
    echo "Loading initrd..."
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell (no desktop)" {
    set gfxpayload=text
    echo "Booting to emergency shell - no X11 startup"
    
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    echo "Loading kernel with emergency parameters..."
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro nomodeset acpi=off pci=noacpi noapic nowatchdog mem=2G usbhid.quirks=0x05ac:0x020b:0x01 i8042.reset i8042.nomux i8042.nopnp i8042.noloop init=/bin/bash
    
    echo "Loading initrd..."
    initrd /boot/initrd.img
}

menuentry "🍃 Thyme OS - Memory Test Boot" {
    set gfxpayload=text
    echo "Booting with memory diagnostics..."
    
    search --set=root --fs-uuid THYME_ROOT_UUID
    
    linux /boot/vmlinuz root=UUID=THYME_ROOT_UUID ro debug memtest=1 verbose
    initrd /boot/initrd.img
}

menuentry "🔧 System Information" {
    echo "Thyme OS System Information"
    echo "=========================="
    echo "GRUB Version: 2.02+"
    echo "Platform: ${grub_platform}"
    echo "CPU: ${grub_cpu}"
    echo "Target: MacBook2,1"
    echo ""
    
    echo "Available devices:"
    ls -l
    echo ""
    
    echo "Memory map:"
    lsmmap
    echo ""
    
    echo "Press any key to return to menu..."
    read
}

menuentry "🔄 Reboot System" {
    echo "Rebooting system..."
    reboot
}

menuentry "⚡ Shutdown System" {
    echo "Shutting down system..."
    halt
}

# Emergency shell (hidden, access with 'c' key)
if keystatus --shift; then
    menuentry "🛠️ GRUB Command Shell" {
        echo "Entering GRUB command shell..."
        echo "Type 'exit' to return to menu"
        echo "Useful commands: ls, cat, boot, linux, initrd"
        echo ""
    }
fi
EOF
    
    # Replace UUID placeholder
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    sudo sed -i "s/THYME_ROOT_UUID/$root_uuid/g" "$grub_cfg"
    
    # Copy to standard boot location
    sudo cp "$grub_cfg" "$EFI_MOUNT_POINT/EFI/BOOT/grub.cfg"
    
    # Copy GRUB modules to fix ext4.mod error
    log "Installing GRUB modules..."
    if [[ -d "/usr/lib/grub/i386-efi" ]]; then
        sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme/i386-efi"
        sudo cp -r "/usr/lib/grub/i386-efi"/* "$EFI_MOUNT_POINT/EFI/thyme/i386-efi/" 2>/dev/null || true
        log "32-bit GRUB modules copied"
    fi
    
    if [[ -d "/usr/lib/grub/x86_64-efi" ]]; then
        sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme/x86_64-efi"
        sudo cp -r "/usr/lib/grub/x86_64-efi"/* "$EFI_MOUNT_POINT/EFI/thyme/x86_64-efi/" 2>/dev/null || true
        log "64-bit GRUB modules copied"
    fi
    
    # Create simplified fallback config
    sudo tee "$EFI_MOUNT_POINT/EFI/BOOT/grub_simple.cfg" > /dev/null << EOF
# Thyme OS - Emergency Configuration
set timeout=30
set default=0

menuentry "Thyme OS Emergency Boot" {
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro
    initrd /boot/initrd.img
}
EOF
    
    log "✅ GRUB configuration created"
}

# Optimize system for MacBook2,1
optimize_for_macbook() {
    log "Applying MacBook2,1 optimizations..."
    
    # Create memory management configuration
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme-memory.conf" > /dev/null << 'EOF'
# Thyme OS Memory Management Configuration
# Optimized for MacBook2,1 (2GB RAM)

# Memory thresholds (in MB)
MEMORY_WARNING_THRESHOLD=1536
MEMORY_CRITICAL_THRESHOLD=1792
SWAP_AGGRESSIVENESS=10

# Process management
AUTO_KILL_HEAVY_PROCESSES=true
HEAVY_PROCESS_THRESHOLD=256

# System optimizations
DISABLE_UNNECESSARY_SERVICES=true
ENABLE_ZRAM=true
ZRAM_SIZE=512M
EOF
    
    # Create initial package list for essential applications
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme-packages.list" > /dev/null << 'EOF'
# Thyme OS Essential Packages
# Applications for daily use on MacBook2,1

# Text editing and office
libreoffice-writer
libreoffice-calc
abiword
gnumeric

# Image editing
gimp
mtpaint

# Web and communication
firefox-esr
thunderbird
claws-mail

# System utilities
htop
neofetch
nano
vim-tiny

# Terminal and development
bash-completion
curl
wget
git
openssh-client

# Multimedia (lightweight)
vlc
audacious
EOF
    
    # Create terminal documentation
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/share/doc/thyme"
    sudo tee "$ROOT_MOUNT_POINT/usr/share/doc/thyme/terminal-guide.txt" > /dev/null << 'EOF'
🍃 Thyme OS Terminal Guide 🍃
=============================

Essential Commands for New Users:

PROCESS MANAGEMENT:
• ps aux          - Show all running processes
• htop            - Interactive process monitor
• kill PID        - Stop a process by ID
• killall NAME    - Stop processes by name

FILE SYSTEM:
• ls              - List files in directory
• ls -la          - List files with details
• lsblk           - Show storage devices
• df -h           - Show disk usage
• cd /path        - Change directory
• pwd             - Show current directory

FILE OPERATIONS:
• nano file.txt   - Edit text file (beginner-friendly)
• cat file.txt    - Display file contents
• grep "text" file - Search for text in file
• find /path -name "*.txt" - Find files
• |               - Pipe output to another command

DISK OPERATIONS:
• sudo dd if=/dev/sda of=/dev/sdb - Copy disk (DANGEROUS!)
• mount /dev/sda1 /mnt - Mount storage device
• umount /mnt     - Unmount device

NETWORK:
• ssh user@host   - Remote login
• scp file user@host:/path - Copy files over network
• ip addr         - Show network interfaces
• ping google.com - Test internet connection

SYSTEM ADMINISTRATION:
• sudo command    - Run command as administrator
• sudo apt update - Update package lists
• sudo apt install package - Install software
• systemctl status service - Check service status

MEMORY MANAGEMENT (Thyme OS specific):
• free -h         - Show memory usage
• thyme-memory    - Memory optimization tool
• thyme-freeze    - Freeze unused processes

TIPS:
• Use TAB key for auto-completion
• Use UP/DOWN arrows for command history
• Ctrl+C stops running commands
• Ctrl+D exits terminal
• man command shows manual for any command

Remember: Practice makes perfect! Start with simple commands
and gradually work your way up to more complex operations.
EOF
    
    # Create startup script for Thyme OS with hardware detection
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme-startup.sh" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS Startup Script
# Hardware detection and optimization

echo "🍃 Thyme OS starting up..."

# Fix PATH and environment first
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Initialize console and keyboard immediately
echo "Initializing keyboard and console input..."

# Load essential input modules
modprobe usbhid 2>/dev/null || true
modprobe hid 2>/dev/null || true  
modprobe i8042 2>/dev/null || true
modprobe atkbd 2>/dev/null || true
modprobe psmouse 2>/dev/null || true

# Set terminal to proper mode
stty sane 2>/dev/null || true
stty echo 2>/dev/null || true
stty -icanon min 1 time 0 2>/dev/null || true

# Load keyboard layout
loadkeys us 2>/dev/null || true
kbd_mode -u 2>/dev/null || true

# Enable swap immediately for low-memory systems  
echo "Activating swap space..."
swapon -a

# Detect MacBook model
MODEL=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "Unknown")
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
CPU_CORES=$(nproc)

echo "Hardware Detection:"
echo "  Model: $MODEL"
echo "  Memory: ${MEMORY_GB}GB"
echo "  CPU Cores: $CPU_CORES"

# Set optimizations based on detected hardware
if [[ "$MEMORY_GB" -le 2 ]]; then
    echo "Low memory system detected - applying aggressive optimization"
    
    # Conservative CPU governor for battery life
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    fi
    
    # Aggressive swap for low memory
    echo 20 > /proc/sys/vm/swappiness
    echo 1 > /proc/sys/vm/overcommit_memory
    
    # Enable ZRAM if available
    if command -v zramctl >/dev/null 2>&1; then
        echo "Setting up ZRAM for memory compression..."
        modprobe zram
        echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
        echo 512M > /sys/block/zram0/disksize
        mkswap /dev/zram0 2>/dev/null && swapon /dev/zram0 2>/dev/null || true
    fi
    
elif [[ "$MEMORY_GB" -ge 4 ]]; then
    echo "Higher memory system detected - enabling performance features"
    
    # Performance CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    fi
    
    # Less aggressive swap
    echo 5 > /proc/sys/vm/swappiness
    
    # Enable graphics acceleration if available
    echo "Enabling graphics acceleration..."
    # This would be expanded based on detected graphics hardware
    
else
    echo "Medium memory system - balanced optimization"
    echo 10 > /proc/sys/vm/swappiness
fi

# MacBook-specific optimizations
case "$MODEL" in
    *MacBook2,1*|*MacBook1,1*|*MacBook3,1*|*MacBook4,1*)
        echo "Vintage MacBook detected - applying compatibility fixes"
        
        # Disable problematic features for old hardware
        modprobe -r pcspkr 2>/dev/null || true
        
        # Conservative power management
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null || true
        
        # Disable USB autosuspend (can cause issues)
        echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true
        ;;
        
    *MacBook5,1*|*MacBook6,1*|*MacBook7,1*)
        echo "Mid-era MacBook detected - balanced settings"
        # Enable more features but keep compatibility
        ;;
        
    *)
        echo "Modern or unknown MacBook - full feature set"
        # Enable all performance features
        ;;
esac

# Start memory monitoring based on available memory
if [[ "$MEMORY_GB" -le 2 ]] && [ -x /usr/bin/thyme-memory ]; then
    echo "Starting aggressive memory monitoring..."
    /usr/bin/thyme-memory --daemon --aggressive &
elif [ -x /usr/bin/thyme-memory ]; then
    echo "Starting standard memory monitoring..."
    /usr/bin/thyme-memory --daemon &
fi

# Create a hardware info file for user reference
cat > /tmp/thyme-hardware-info << HWEOF
🍃 Thyme OS Hardware Detection Report
====================================

Model: $MODEL
Memory: ${MEMORY_GB}GB RAM
CPU Cores: $CPU_CORES
Boot Mode: $(cat /proc/cmdline | grep -o 'nomodeset\|acpi=off' | tr '\n' ' ' || echo "Standard")

Optimizations Applied:
$([ "$MEMORY_GB" -le 2 ] && echo "✓ Low memory optimizations" || echo "✓ Standard memory management")
$([ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] && echo "✓ CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)")
$([ -e /dev/zram0 ] && echo "✓ ZRAM compression enabled" || echo "○ ZRAM not available")

To view this report: cat /tmp/thyme-hardware-info
HWEOF

echo "🍃 Thyme OS ready! Hardware report: /tmp/thyme-hardware-info"
EOF
    sudo chmod +x "$ROOT_MOUNT_POINT/etc/thyme-startup.sh"
    
    log "✅ MacBook2,1 optimizations applied"
}

# Validate installation
validate_installation() {
    log "Validating installation integrity..."
    
    local validation_errors=0
    
    # Check critical executables
    local critical_files=(
        "/sbin/init"
        "/bin/bash"
        "/bin/sh"
        "/bin/ls"
        "/bin/mkdir"
        "/bin/chmod"
        "/usr/bin/loadkeys"
        "/sbin/modprobe"
        "/sbin/swapon"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$ROOT_MOUNT_POINT$file" ]]; then
            warn "Missing critical file: $file"
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    # Check critical directories
    local critical_dirs=(
        "/etc"
        "/var/log"
        "/dev"
        "/proc"
        "/sys"
        "/tmp"
        "/home/thyme"
        "/boot"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [[ ! -d "$ROOT_MOUNT_POINT$dir" ]]; then
            warn "Missing critical directory: $dir"
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    # Check if keyboard files exist
    if [[ ! -d "$ROOT_MOUNT_POINT/usr/share/kbd" ]] && [[ ! -d "$ROOT_MOUNT_POINT/usr/share/keymaps" ]]; then
        warn "No keyboard layout files found - keyboard may not work"
        validation_errors=$((validation_errors + 1))
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log "✅ Installation validation passed"
    else
        warn "⚠️ Installation validation found $validation_errors issues (system may still boot)"
    fi
    
    export validation_errors
}

# Final system configuration
finalize_installation() {
    log "Finalizing installation..."
    
    # Set proper permissions
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme"
    sudo chmod 755 "$ROOT_MOUNT_POINT/home/thyme"
    
    # Create installation info file
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme-install-info.txt" > /dev/null << EOF
Thyme OS Installation Information
================================

Installation Date: $(date)
Target Device: $TARGET_DEVICE
EFI Partition: $EFI_PARTITION
Root Partition: $ROOT_PARTITION
Root UUID: $(sudo blkid -s UUID -o value "$ROOT_PARTITION")
EFI UUID: $(sudo blkid -s UUID -o value "$EFI_PARTITION")

Hardware Optimization: MacBook2,1
GRUB Bootloader: 32-bit + 64-bit EFI
Installer Version: $SCRIPT_VERSION

Next Steps:
1. Install Linux kernel and initrd to /boot/
2. Install package manager and essential packages
3. Configure network and user accounts
4. Test boot from this SSD

For support: Check /usr/share/doc/thyme/terminal-guide.txt
EOF
    
    log "✅ Installation finalized"
}

# Cleanup and unmount
cleanup_and_finish() {
    log "Cleaning up installation..."
    
    # Sync all pending writes
    sync
    
    # Unmount filesystems
    if mountpoint -q "$ROOT_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$ROOT_MOUNT_POINT"
        log "Root partition unmounted"
    fi
    
    if mountpoint -q "$EFI_MOUNT_POINT" 2>/dev/null; then
        sudo umount "$EFI_MOUNT_POINT"
        log "EFI partition unmounted"
    fi
    
    # Remove work directory
    cd /tmp
    rm -rf "$WORK_DIR"
    
    log "✅ Cleanup completed"
}

# Show installation summary
show_summary() {
    echo -e "${GREEN}"
    cat << EOF

🎉 Thyme OS SSD Installation Complete! 🎉

Installation Summary:
═══════════════════════════════════════
• Target Device: $TARGET_DEVICE
• EFI Partition: $EFI_PARTITION (FAT32, 512MB)
• Swap Partition: $SWAP_PARTITION (Linux Swap, auto-sized)
• Root Partition: $ROOT_PARTITION (ext4, remaining space)
• GRUB Bootloader: User-selected EFI architecture
• MacBook Optimization: Hardware-adaptive scaling

Next Steps:
═══════════════════════════════════════
1. 📦 Complete the OS installation:
   • Install Linux kernel and modules
   • Install package manager (apt/dnf)
   • Install essential packages

2. 🔧 System Configuration:
   • Set up users and passwords
   • Configure network settings
   • Install drivers for MacBook hardware

3. 🚀 Testing:
   • Connect SSD to MacBook2,1
   • Boot and test GRUB menu
   • Verify hardware compatibility

Installation Files:
═══════════════════════════════════════
• Installation log: $INSTALL_LOG
• System info: /etc/thyme-install-info.txt
• Terminal guide: /usr/share/doc/thyme/terminal-guide.txt
• Memory config: /etc/thyme-memory.conf

🍃 Your MacBook2,1 is ready for Thyme OS! 🍃

EOF
    echo -e "${NC}"
}

# Main installation function
main() {
    initialize_installer
    
    if [[ "$AUTO_INSTALL_MODE" == "true" ]]; then
        log "🚀 AUTO-INSTALL MODE: Proceeding with installation automatically"
        confirm="y"
    else
        read -p "Continue with Thyme OS SSD installation? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]] && [[ "${confirm,,}" != "yes" ]]; then
            error "Installation cancelled by user"
        fi
    fi
    
    log "🍃 Starting Thyme OS SSD installation..."
    
    # Collect all user choices first
    check_requirements
    detect_target_device
    choose_efi_architecture
    choose_desktop_environment
    
    # Show installation plan summary
    show_installation_plan
    
    # Perform installation
    partition_device
    format_partitions
    mount_partitions
    install_base_system
    install_kernel
    install_desktop_environment
    install_grub
    optimize_for_macbook
    validate_installation
    finalize_installation
    cleanup_and_finish
    
    show_summary
    
    log "🎉 Thyme OS SSD installation completed successfully!"
}

# Run main installation
main "$@"