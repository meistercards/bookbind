# OBJECTIVE
You're working on creating BookBind, a streamlined Linux installer that burns optimized Linux installations directly to SSDs for old MacBooks that can't boot from standard LiveUSB drives.

The project pivots from OS development to creating a simple tool that takes any Linux distribution running on a host computer and burns it directly onto an SSD through USB-to-SATA connection, removing unnecessary programs and applying memory/CPU optimizations to prevent freezing on old MacBook hardware.

# CODE SNIPPETS
These are suggested code snippets to follow/guide the implementation:

`bookbind.sh` - Main installer script header:
```bash
#!/bin/bash
# BookBind Linux Installer v1.0
# Streamlined Linux installer for old MacBooks
# Burns optimized Linux installations to SSD via USB-to-SATA

set -e

SCRIPT_VERSION="1.0-bookbind"
INSTALL_LOG="/var/log/bookbind_install.log"
GRUB_FILES_DIR="$(dirname "$(readlink -f "$0")")/grub_files"
WORK_DIR="/tmp/bookbind_work"
TEST_MODE=${1:-"normal"}  # normal, test, debug
AUTO_CONFIRM=${AUTO_CONFIRM:-"false"}

# Distribution detection
detect_host_distribution() {
    if [[ -f "/etc/lsb-release" ]] && grep -q "DISTRIB_ID=LinuxMint" /etc/lsb-release; then
        DISTRO="mint"
    elif [[ -f "/etc/lsb-release" ]] && grep -q "DISTRIB_ID=Ubuntu" /etc/lsb-release; then
        DISTRO="ubuntu"
    elif [[ -f "/etc/debian_version" ]]; then
        DISTRO="debian"
    else
        DISTRO="unknown"
    fi
    export DISTRO
}
```

`distributions/mint.conf` - Distribution-specific configuration:
```bash
# Linux Mint specific configuration for BookBind
DISTRO_NAME="Linux Mint"
DISTRO_ID="mint"

# Bloatware patterns specific to Mint
MINT_BLOATWARE_PATTERNS=(
    "/usr/games/*"
    "/usr/lib/libreoffice/*"
    "/usr/bin/thunderbird*"
    "/usr/bin/rhythmbox*"
    "/usr/bin/hexchat*"
    "/usr/bin/webapp-manager*"
    "/usr/bin/mintwelcome*"
    "/snap/*"
    "/var/lib/snapd/*"
)

# Essential packages to preserve
MINT_ESSENTIAL_PACKAGES=(
    "firefox"
    "thunar"
    "xfce4-terminal"
    "network-manager"
    "pulseaudio"
)
```

# IMPORTANT NOTES
- **Safety First**: Multiple confirmations required before any destructive operations on target SSDs
- **USB-to-SATA Focus**: Primary installation method is external SSD connected via USB-to-SATA adapter
- **Memory Optimization**: Critical for 2-4GB RAM systems - must remove bloatware during copy, not after
- **32-bit EFI Requirement**: Old MacBooks need 32-bit EFI bootloader (grubia32.efi) to boot
- **Freeze Prevention**: Incorporate thermal monitoring and CPU optimization from existing mintbook system
- **Distribution Agnostic**: Must work with any Linux distribution as host system
- **Test Mode**: Include safe testing with loop devices to avoid hardware damage during development
- **Grub Files Dependency**: Requires grubia32.efi file in grub_files/ directory
- **Backup Host System**: Never modify the running host system, only copy from it
- **Error Recovery**: Comprehensive cleanup on failure with proper unmounting and device release

# TASK LIST
- [ ] Phase 1: Core Infrastructure
  - [ ] Create `bookbind.sh` main installer script adapted from `mintbook/thyme_installer.sh`
  - [ ] Implement distribution detection system in `bookbind.sh`
  - [ ] Create `distributions/` directory with configuration files
  - [ ] Create `distributions/mint.conf` with Linux Mint specific patterns
  - [ ] Create `distributions/ubuntu.conf` with Ubuntu specific patterns
  - [ ] Create `distributions/debian.conf` with Debian specific patterns
  - [ ] Copy `grub_files/grubia32.efi` from mintbook to bookbind
- [ ] Phase 2: Smart Copy Engine
  - [ ] Implement multi-distribution bloatware detection in `bookbind.sh`
  - [ ] Create dynamic exclusion pattern system based on detected distribution
  - [ ] Add safety validation for essential system libraries
  - [ ] Implement USB-to-SATA specific device detection and validation
  - [ ] Add device naming consistency handling for external SSDs
- [ ] Phase 3: Hardware Optimization
  - [ ] Create `optimizations/memory_management.sh` script
  - [ ] Create `optimizations/thermal_control.sh` script 
  - [ ] Create `optimizations/macbook_fixes.sh` script
  - [ ] Integrate freeze monitoring system from `mintbook/built_in_features/`
  - [ ] Implement first-boot setup wizard adapted from thyme installer
- [ ] Phase 4: Testing Framework
  - [ ] Create `testing/boot_test.sh` for validating installations
  - [ ] Create `testing/hardware_test.sh` for MacBook compatibility
  - [ ] Create `testing/performance_test.sh` for memory/CPU validation
  - [ ] Implement test mode with loop devices for safe development testing
  - [ ] Create comprehensive device detection testing
- [ ] Phase 5: Documentation and Safety
  - [ ] Create `docs/installation_guide.md` with step-by-step instructions
  - [ ] Create `docs/troubleshooting.md` with common issues and solutions
  - [ ] Create `docs/hardware_compatibility.md` with tested MacBook models
  - [ ] Add comprehensive safety warnings and confirmations to installer
  - [ ] Create recovery procedures documentation
- [ ] Phase 6: Integration Testing
  - [ ] Test installation process with Linux Mint as host system
  - [ ] Test installation process with Ubuntu as host system
  - [ ] Validate USB-to-SATA workflow on real hardware
  - [ ] Test first-boot experience on target MacBook hardware
  - [ ] Validate memory optimization effectiveness on 2GB RAM systems
  - [ ] Test freeze prevention under CPU load
- [ ] Phase 7: Final Validation
  - [ ] Run complete installation test on MacBook2,1 hardware
  - [ ] Validate 32-bit EFI boot process
  - [ ] Test system stability for 24+ hours
  - [ ] Verify all documentation matches actual functionality
  - [ ] Create final safety checklist for users