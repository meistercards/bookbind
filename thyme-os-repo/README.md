# Thyme OS

<p align="center">
  <img src="branding/logo.svg" alt="Thyme OS Logo" width="120" height="120">
</p>

<h1 align="center">Thyme OS</h1>
<p align="center">
  <strong>Linux for MacBooks</strong><br>
  Revive your vintage MacBook with modern Linux compatibility
</p>

<p align="center">
  <a href="https://github.com/thyme-os/thyme-os/releases"><img src="https://img.shields.io/github/v/release/thyme-os/thyme-os?style=flat-square&logo=github" alt="Latest Release"></a>
  <a href="https://github.com/thyme-os/thyme-os/blob/main/LICENSE"><img src="https://img.shields.io/github/license/thyme-os/thyme-os?style=flat-square" alt="License"></a>
  <a href="https://github.com/thyme-os/thyme-os/issues"><img src="https://img.shields.io/github/issues/thyme-os/thyme-os?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/thyme-os/thyme-os/discussions"><img src="https://img.shields.io/github/discussions/thyme-os/thyme-os?style=flat-square" alt="Discussions"></a>
</p>

---

## 🍃 What is Thyme OS?

Thyme OS is a specialized Linux distribution based on **Linux Mint XFCE**, designed specifically for **vintage MacBooks (2006-2009)** with 32-bit EFI firmware. It solves the fundamental problem that prevents standard Linux LiveUSBs from booting on these machines.

### ⚡ Key Features

- **🔧 Five Bootstrap Methods** - Multiple ways to install on old MacBooks
- **🛌 Sleep/Wake Fixes** - No more freeze issues on sleep/resume
- **🌡️ Thermal Management** - Intelligent temperature monitoring and fan control
- **📱 Hardware Optimization** - MacBook-specific drivers and configurations  
- **🎯 32-bit EFI Support** - Purpose-built for problematic EFI firmware
- **🔄 Memory Management** - Optimized for 1-4GB RAM systems

### 🖥️ Supported Hardware

| MacBook Model | Year | Status | Bootstrap Methods |
|---------------|------|--------|-------------------|
| MacBook2,1 | 2006-2007 | ✅ **Fully Tested** | All methods |
| MacBook1,1 - MacBook4,1 | 2006-2008 | 📋 Ready for testing | All methods |
| MacBookPro1,1 - MacBookPro3,1 | 2006-2007 | 📋 Ready for testing | All methods |

*[View complete compatibility matrix →](docs/hardware/compatibility_matrix.md)*

---

## 🚀 Quick Start

### Choose Your Installation Method

#### 1. **SSD Swap Method** ⭐ *Most Reliable*
Remove MacBook's SSD, install on modern computer, swap back.
```bash
python3 bootstrap/ssd_swap/installer_override.py dialog
```

#### 2. **macOS Installer** 🍎 *Most Convenient*
Install from macOS Terminal (Snow Leopard - Mountain Lion).
```bash
bash bootstrap/macos_installer/macos_grub_installer.sh
```

#### 3. **Network Installation** 🌐 *For Advanced Users*
Install over Ethernet connection.
```bash
python3 bootstrap/network/network_installer.py server thyme-os.iso
```

*[View all installation methods →](docs/installation/bootstrap_methods.md)*

### 📥 Download

- **Latest Release**: [Download ISO](https://github.com/thyme-os/thyme-os/releases/latest)
- **Hardware Tools**: [Bootstrap Scripts](https://github.com/thyme-os/thyme-os/tree/main/bootstrap)
- **Documentation**: [Installation Guide](docs/installation/)

---

## 🏗️ The MacBook Problem Solved

### The Challenge
Old MacBooks (2006-2009) have **32-bit EFI firmware** but **64-bit processors**. Standard Linux distributions create 64-bit EFI bootloaders that these machines cannot load, making installation impossible through normal methods.

### The Solution
Thyme OS provides **five different bootstrap methods** to work around this limitation:

1. **SSD Swap** - Install on external computer, transfer drive
2. **macOS Installer** - Install GRUB from existing macOS  
3. **Network Boot** - PXE installation over Ethernet
4. **Rescue System** - Minimal bootable system for SSD preparation
5. **Hybrid USB** - Dual-architecture LiveUSB (experimental)

---

## 🧪 Development & Testing

### Build from Source
```bash
git clone https://github.com/thyme-os/thyme-os.git
cd thyme-os
python3 build/build_system.py create --hardware macbook2_1
```

### Hardware Testing
We actively test on real MacBook hardware. Join our testing program:
```bash
python3 testing/hardware_tests/submit_report.py
```

### Contributing
- **Hardware Testing**: Test on your MacBook model
- **Bootstrap Methods**: Improve installation compatibility  
- **Documentation**: Help other users with guides
- **Code**: Fix bugs, add features, optimize performance

*[View contributing guide →](CONTRIBUTING.md)*

---

## 🏆 Community & Support

- **💬 [Discussions](https://github.com/thyme-os/thyme-os/discussions)** - Community support and questions
- **🐛 [Issues](https://github.com/thyme-os/thyme-os/issues)** - Bug reports and feature requests  
- **📖 [Wiki](https://github.com/thyme-os/thyme-os/wiki)** - Community documentation
- **🔧 [Hardware Database](community/hardware_database/)** - Community hardware testing

### Recognition Program
- **🥇 Pioneer Badge** - First to test new MacBook model
- **🔬 Validator Badge** - Confirm hardware compatibility
- **🛠️ Contributor Badge** - Submit fixes or improvements

---

## 📋 Project Status

### Current Development
- **✅ Core System**: Stable freeze monitoring and thermal management
- **✅ Bootstrap Methods**: Five working installation methods
- **✅ MacBook2,1**: Fully tested and optimized
- **🧪 Hardware Expansion**: Testing additional MacBook models
- **🔄 Community Tools**: Hardware database and testing framework

### Roadmap
- **Phase 1**: Perfect 32-bit EFI MacBook support (2006-2009)
- **Phase 2**: Optimize mixed EFI models (2008-2009)  
- **Phase 3**: Advanced optimizations for vintage hardware
- **Phase 4**: Community-driven hardware expansion

---

## 📜 License

Thyme OS is released under the **GPL-3.0 License**. This ensures the project remains free and open-source.

- **Base System**: Linux Mint components retain their original licenses
- **Thyme Modifications**: GPL-3.0 licensed
- **Bootstrap Scripts**: GPL-3.0 licensed  
- **Documentation**: Creative Commons licensed

---

## ⚡ Why "Thyme"?

**Thyme** is a play on **"Time"** - extending the useful lifetime of vintage MacBook hardware. Like the herb thyme that preserves and enhances, Thyme OS preserves and enhances the capabilities of aging MacBooks.

---

<p align="center">
  <strong>Revive your MacBook. Join the Thyme OS community.</strong>
</p>

<p align="center">
  <a href="https://github.com/thyme-os/thyme-os/releases">Download</a> •
  <a href="docs/installation/bootstrap_methods.md">Install</a> •
  <a href="docs/hardware/compatibility_matrix.md">Hardware</a> •  
  <a href="https://github.com/thyme-os/thyme-os/discussions">Community</a>
</p>
