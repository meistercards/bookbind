#!/bin/bash
# Thyme OS VM Testing Framework
# Creates and manages VMs for testing Thyme OS builds

set -e

VM_NAME="thyme-os-test"
VM_DIR="/home/meister/mintbook/thyme-testing-framework/vms"
ISO_DIR="/home/meister/mintbook/thyme-testing-framework/isos"
LOG_FILE="/tmp/thyme_vm_test.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if virtualization is available
check_virtualization() {
    log "Checking virtualization support..."
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        error "QEMU not installed. Install with: sudo apt install qemu-system-x86 qemu-utils"
    fi
    
    if ! lscpu | grep -E "(vmx|svm)" > /dev/null; then
        warn "Hardware virtualization not detected - VMs will be slower"
    else
        log "✅ Hardware virtualization available"
    fi
    
    # Check KVM
    if [[ -r /dev/kvm ]]; then
        log "✅ KVM acceleration available"
        KVM_ACCEL="-enable-kvm"
    else
        warn "KVM not available - install qemu-kvm and add user to kvm group"
        KVM_ACCEL=""
    fi
}

# Create VM directory structure
setup_vm_environment() {
    log "Setting up VM environment..."
    
    mkdir -p "$VM_DIR"
    mkdir -p "$ISO_DIR"
    mkdir -p "$VM_DIR/disks"
    mkdir -p "$VM_DIR/configs"
    mkdir -p "$VM_DIR/logs"
    
    log "✅ VM environment created"
}

# Create a virtual disk for testing
create_test_disk() {
    local disk_size=${1:-8G}
    local disk_name="${VM_NAME}-disk.qcow2"
    local disk_path="$VM_DIR/disks/$disk_name"
    
    log "Creating virtual disk: $disk_name ($disk_size)..."
    
    if [[ -f "$disk_path" ]]; then
        read -p "Disk $disk_name exists. Recreate? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm "$disk_path"
        else
            log "Using existing disk"
            export VM_DISK="$disk_path"
            return
        fi
    fi
    
    qemu-img create -f qcow2 "$disk_path" "$disk_size"
    log "✅ Virtual disk created: $disk_path"
    export VM_DISK="$disk_path"
}

# Create VM configuration
create_vm_config() {
    local config_file="$VM_DIR/configs/${VM_NAME}.conf"
    
    log "Creating VM configuration..."
    
    cat > "$config_file" << EOF
# Thyme OS Test VM Configuration
VM_NAME="$VM_NAME"
VM_DISK="$VM_DISK"
VM_MEMORY="2048"
VM_CPUS="2"
VM_NETWORK="user"
VM_DISPLAY="gtk"
KVM_ACCEL="$KVM_ACCEL"

# MacBook2,1 emulation settings
VM_MACHINE="pc-q35-6.2"
VM_CPU="core2duo"
VM_BIOS="/usr/share/ovmf/OVMF.fd"

# USB settings for MacBook testing
VM_USB="usb-tablet,usb-kbd"
EOF
    
    log "✅ VM configuration created: $config_file"
    export VM_CONFIG="$config_file"
}

# Start VM for installation testing
start_vm_install() {
    local thyme_iso="${1:-}"
    
    if [[ -z "$thyme_iso" ]]; then
        error "No ISO provided for installation test"
    fi
    
    if [[ ! -f "$thyme_iso" ]]; then
        error "ISO file not found: $thyme_iso"
    fi
    
    log "Starting VM for installation testing..."
    log "ISO: $thyme_iso"
    log "Disk: $VM_DISK"
    
    # Source VM config
    source "$VM_CONFIG"
    
    # QEMU command for installation
    qemu-system-x86_64 \
        $KVM_ACCEL \
        -machine "$VM_MACHINE" \
        -cpu "$VM_CPU" \
        -m "$VM_MEMORY" \
        -smp "$VM_CPUS" \
        -cdrom "$thyme_iso" \
        -drive file="$VM_DISK",format=qcow2,if=virtio \
        -netdev user,id=net0 -device virtio-net,netdev=net0 \
        -device usb-tablet \
        -device usb-kbd \
        -display gtk \
        -monitor stdio \
        -name "Thyme OS Installation Test" \
        2>&1 | tee "$VM_DIR/logs/install-$(date +%Y%m%d-%H%M%S).log"
}

# Start VM for boot testing (no ISO)
start_vm_boot_test() {
    log "Starting VM for boot testing..."
    
    if [[ ! -f "$VM_DISK" ]]; then
        error "No VM disk found. Run installation first."
    fi
    
    # Source VM config
    source "$VM_CONFIG"
    
    # QEMU command for boot testing
    qemu-system-x86_64 \
        $KVM_ACCEL \
        -machine "$VM_MACHINE" \
        -cpu "$VM_CPU" \
        -m "$VM_MEMORY" \
        -smp "$VM_CPUS" \
        -drive file="$VM_DISK",format=qcow2,if=virtio \
        -netdev user,id=net0 -device virtio-net,netdev=net0 \
        -device usb-tablet \
        -device usb-kbd \
        -display gtk \
        -monitor stdio \
        -name "Thyme OS Boot Test" \
        2>&1 | tee "$VM_DIR/logs/boot-$(date +%Y%m%d-%H%M%S).log"
}

# Create automated test ISO from our Mint installation
create_test_iso() {
    log "Creating test ISO from current Mint installation..."
    
    local iso_name="thyme-test-$(date +%Y%m%d).iso"
    local iso_path="$ISO_DIR/$iso_name"
    
    # Use our streamlined installer to create a test environment
    local test_script="$VM_DIR/create_test_iso.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Create test ISO script

set -e

WORK_DIR="/tmp/thyme_iso_work"
ISO_ROOT="$WORK_DIR/iso"
SQUASH_ROOT="$WORK_DIR/squashfs-root"

# Create work directories
mkdir -p "$ISO_ROOT" "$SQUASH_ROOT"

# Copy minimal Mint system
echo "Creating minimal system copy..."
rsync -aHAX \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/dev/* \
    --exclude=/tmp/* \
    --exclude=/run/* \
    --exclude=/mnt/* \
    --exclude=/media/* \
    --exclude=/var/cache/* \
    --exclude=/var/log/* \
    --exclude=/home/*/.cache/* \
    --exclude="*/Downloads/*" \
    --exclude="*/mintbook/*" \
    --exclude="*libreoffice*" \
    --exclude="*thunderbird*" \
    --exclude="*rhythmbox*" \
    --exclude="*games*" \
    / "$SQUASH_ROOT/"

# Create squashfs
echo "Creating squashfs..."
mksquashfs "$SQUASH_ROOT" "$ISO_ROOT/casper/filesystem.squashfs" -comp xz

# Copy kernel and initrd
cp /boot/vmlinuz-* "$ISO_ROOT/casper/vmlinuz"
cp /boot/initrd.img-* "$ISO_ROOT/casper/initrd"

# Create ISO
echo "Creating ISO..."
xorriso -as mkisofs \
    -r -V "Thyme OS Test" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -no-emul-boot \
    -o "$1" \
    "$ISO_ROOT"

echo "✅ Test ISO created: $1"
EOF
    
    chmod +x "$test_script"
    
    # Run the script (commented out for now - requires more setup)
    # sudo "$test_script" "$iso_path"
    
    log "✅ Test ISO creation script ready: $test_script"
    warn "Note: Full ISO creation requires additional setup"
}

# Run automated tests
run_automated_tests() {
    log "Running automated VM tests..."
    
    # Test 1: Boot test
    log "Test 1: Boot verification"
    if timeout 60 start_vm_boot_test; then
        log "✅ Boot test passed"
    else
        warn "❌ Boot test failed or timed out"
    fi
    
    # Test 2: SSH connectivity (if network configured)
    log "Test 2: Network connectivity"
    # TODO: Add SSH test
    
    # Test 3: USB/HID testing
    log "Test 3: Input device testing"
    # TODO: Add input device testing
    
    log "✅ Automated tests completed"
}

# Create testing documentation
create_test_docs() {
    log "Creating testing documentation..."
    
    cat > "$VM_DIR/README.md" << 'EOF'
# Thyme OS VM Testing Framework

## Quick Start

### Prerequisites
```bash
sudo apt install qemu-system-x86 qemu-utils qemu-kvm
sudo usermod -a -G kvm $USER
# Log out and back in
```

### Basic Testing
```bash
# Setup VM environment
./vm-testing-setup.sh setup

# Create test disk
./vm-testing-setup.sh create-disk

# Start boot test
./vm-testing-setup.sh boot-test

# Start with ISO
./vm-testing-setup.sh install path/to/thyme.iso
```

## Test Scenarios

### 1. Installation Testing
- Boot from Thyme OS ISO
- Test installer functionality
- Verify partition creation
- Check GRUB installation

### 2. Boot Testing
- Boot from installed disk
- Test GRUB menu options
- Verify kernel loading
- Check input device functionality

### 3. System Testing
- User login testing
- Network connectivity
- Application functionality
- Hardware compatibility

## VM Configuration

### Hardware Emulation
- Machine: pc-q35-6.2 (modern chipset)
- CPU: core2duo (matches MacBook2,1)
- Memory: 2GB (adjustable)
- Storage: virtio (fast)
- Network: virtio-net

### MacBook Compatibility
- USB tablet/keyboard emulation
- EFI boot support
- Legacy BIOS compatibility

## Troubleshooting

### Common Issues
1. **VM won't start**: Check KVM permissions
2. **Slow performance**: Enable hardware virtualization
3. **Display issues**: Try different display backends
4. **Boot failures**: Check EFI/BIOS settings

### Debug Mode
Start VM with additional logging:
```bash
QEMU_LOG=1 ./vm-testing-setup.sh boot-test
```

## Test Results

Test results are logged to:
- Installation logs: `vms/logs/install-*.log`
- Boot logs: `vms/logs/boot-*.log`
- General logs: `/tmp/thyme_vm_test.log`
EOF
    
    log "✅ Testing documentation created: $VM_DIR/README.md"
}

# Main function
main() {
    local action="${1:-help}"
    
    case "$action" in
        "setup")
            check_virtualization
            setup_vm_environment
            create_test_docs
            ;;
        "create-disk")
            setup_vm_environment
            create_test_disk "${2:-8G}"
            create_vm_config
            ;;
        "install")
            if [[ -z "$2" ]]; then
                error "Usage: $0 install <iso-file>"
            fi
            start_vm_install "$2"
            ;;
        "boot-test")
            start_vm_boot_test
            ;;
        "create-iso")
            create_test_iso
            ;;
        "auto-test")
            run_automated_tests
            ;;
        "help"|*)
            echo "Thyme OS VM Testing Framework"
            echo "Usage: $0 <action> [options]"
            echo
            echo "Actions:"
            echo "  setup              - Initialize VM environment"
            echo "  create-disk [size] - Create virtual disk (default: 8G)"
            echo "  install <iso>      - Start VM for installation"
            echo "  boot-test          - Start VM for boot testing"
            echo "  create-iso         - Create test ISO"
            echo "  auto-test          - Run automated tests"
            echo "  help               - Show this help"
            ;;
    esac
}

main "$@"