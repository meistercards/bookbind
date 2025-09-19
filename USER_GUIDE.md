# Thyme OS User Guide

**🍃 Linux for Old MacBooks**

Thyme OS is a specialized Linux distribution designed specifically for old MacBooks (2006-2009) that can't run modern operating systems or boot standard Linux distributions.

## Quick Start

### Do You Need Thyme OS?

**Thyme OS is for you if:**
- You have a MacBook from 2006-2009
- Your MacBook can't boot from Linux LiveUSB drives
- macOS is too slow or no longer supported
- You want to give your old MacBook new life

**You probably don't need Thyme OS if:**
- Your MacBook is from 2010 or newer
- You can already boot Linux LiveUSBs successfully
- Your MacBook runs macOS well

## Supported Hardware

### Fully Tested & Supported ✅
- **MacBookPro2,2** (2006, Core 2 Duo) - *Extensively tested*

### Should Work (32-bit EFI) 🔧
- MacBook1,1 (2006, Core Duo)
- MacBook2,1 (2006-2007, Core 2 Duo)  
- MacBook3,1 (2007, Core 2 Duo)
- MacBook4,1 (2008, Core 2 Duo)
- MacBookPro1,1 (2006, Core Duo)
- MacBookPro2,1 (2006, Core 2 Duo)
- MacBookPro3,1 (2007, Core 2 Duo)

### Mixed Compatibility ⚠️
- MacBook5,1-5,2 (2008-2009) - *May work with standard Linux*
- MacBookPro4,1-5,1 (2008) - *Testing needed*

## Installation Methods

The biggest challenge with old MacBooks is that they **cannot boot from standard Linux LiveUSBs** due to 32-bit EFI firmware. Thyme OS provides several solutions:

### Method 1: macOS GRUB Installer ⭐ **EASIEST**

**Best for:** MacBooks still running Snow Leopard (10.6) through Mountain Lion (10.8)

**Time:** 15-20 minutes

**Steps:**
1. Download `thyme-os-bootstrap-tools.zip` on another computer
2. Transfer to MacBook via USB drive or network
3. Open Terminal on MacBook
4. Run: `bash macos_grub_installer.sh`
5. Follow prompts to install 32-bit EFI bootloader
6. Reboot - MacBook can now boot from LiveUSB!

**Pros:** ✅ Works entirely from within macOS ✅ No hardware disassembly  
**Cons:** ⚠️ Requires working macOS installation

---

### Method 2: SSD Swap Method ⭐ **MOST RELIABLE**

**Best for:** Any situation, especially if macOS is broken

**Time:** 30-45 minutes

**Steps:**
1. **Remove SSD from MacBook**
   - Power off MacBook completely
   - Remove battery (if removable)
   - Unscrew bottom panel
   - Carefully disconnect and remove SSD

2. **Install SSD in modern computer**
   - Use USB-to-SATA adapter or install internally
   - Boot modern computer with Thyme OS LiveUSB

3. **Install Thyme OS with special settings**
   - Boot Thyme OS LiveUSB on modern computer
   - Run installer with forced 32-bit EFI mode:
     ```bash
     python3 installer_override.py configure --force-32bit
     ```
   - Install Thyme OS normally to the MacBook SSD

4. **Move SSD back to MacBook**
   - Shut down modern computer
   - Remove SSD and reinstall in MacBook
   - Boot MacBook - it now runs Thyme OS!

**Pros:** ✅ Always works ✅ No dependency on macOS ✅ Full control  
**Cons:** ⚠️ Requires SSD removal ⚠️ Need second computer

---

### Method 3: Network Installation 🔧 **FOR ADVANCED USERS**

**Best for:** Multiple MacBooks, advanced users with network setup capability

**Time:** 60 minutes setup, 30 minutes per MacBook

**Steps:**
1. **Set up network boot server** (on modern computer):
   ```bash
   python3 network_installer.py server thyme-os.iso
   ```

2. **Boot MacBook from network**:
   - Connect MacBook to Ethernet
   - Hold 'N' key while powering on
   - Select network boot when prompted

3. **Install normally** once network boot completes

**Pros:** ✅ Works over network ✅ No hardware disassembly ✅ Scalable  
**Cons:** ⚠️ Requires Ethernet connection ⚠️ Complex setup ⚠️ Not all MacBooks support netboot

---

### Method 4: Rescue System 🛠️ **DEVELOPMENT**

**Best for:** Systems with working DVD drives or when other methods fail

**Time:** 40 minutes

**Steps:**
1. **Create rescue DVD/USB** (on modern computer):
   ```bash
   python3 rescue_system.py build
   # Burn to DVD or create bootable USB
   ```

2. **Boot MacBook from rescue media**
3. **Use rescue tools** to prepare internal SSD
4. **Reboot** - MacBook can now boot from LiveUSB

**Status:** 🚧 Currently in development

---

## After Installation

### First Boot

When Thyme OS starts for the first time:

1. **Desktop Environment**: You'll see XFCE desktop (lightweight and fast)
2. **Freeze Monitoring**: Automatic monitoring starts to prevent system freezes
3. **Hardware Detection**: System will detect and configure MacBook-specific features

### Key Features

#### ✅ **Sleep/Wake Fixes**
- Your MacBook can sleep and wake up properly
- No more freeze-on-wake issues
- Automatic service recovery after resume

#### ✅ **Thermal Management**
- Real-time temperature monitoring
- Automatic fan control
- Freeze prevention based on thermal conditions

#### ✅ **Memory Optimization**
- Optimized for 2-4GB RAM systems
- Intelligent memory management
- Leak detection and prevention

#### ✅ **MacBook Hardware Support**
- Wi-Fi works out of the box
- Audio and video fully functional
- Trackpad gestures and keyboard shortcuts
- Function key controls (brightness, volume, etc.)

### Performance Tips

#### For 2GB RAM Systems:
- Use lightweight applications (Firefox vs Chrome)
- Close unused programs
- Enable swap if needed

#### For Optimal Performance:
- Keep desktop effects minimal
- Use SSD if possible
- Regularly update system

### Troubleshooting

#### **MacBook won't boot from LiveUSB**
- **Cause**: 32-bit EFI not installed yet
- **Solution**: Use one of the bootstrap methods above

#### **System freezes during use**
- **Check**: Freeze monitoring status
  ```bash
  systemctl status thyme-freeze-monitor
  ```
- **Solution**: Monitor temperatures, reduce CPU load

#### **Sleep/wake doesn't work**
- **Check**: Sleep fixes are applied
- **Solution**: Run sleep fix installer:
  ```bash
  sudo /usr/local/bin/thyme-monitoring/apply-sleep-fixes.sh
  ```

#### **Wi-Fi not working**
- **Check**: Network interfaces
  ```bash
  ip link show
  ```
- **Solution**: Install proprietary drivers if needed

#### **System is slow**
- **Check**: Memory usage
  ```bash
  free -h
  htop
  ```
- **Solution**: Close unused programs, add swap

## Community & Support

### Getting Help

1. **Built-in Diagnostics**:
   ```bash
   python3 /usr/local/bin/debug_system.py report
   ```

2. **Hardware Information**:
   ```bash
   python3 /usr/local/bin/debug_system.py macbook
   ```

3. **System Status**:
   ```bash
   python3 /usr/local/bin/debug_system.py
   ```

### Contributing

#### **Hardware Testing**
Help test Thyme OS on different MacBook models:
1. Try installation on your hardware
2. Report success/failure with model details
3. Share performance observations

#### **Documentation**
- Improve installation guides
- Add troubleshooting solutions
- Create video tutorials

#### **Bug Reports**
When reporting issues, include:
- MacBook model (exact identifier)
- Installation method used
- System diagnostic report
- Steps to reproduce issue

### Hardware Database

Help build the community hardware compatibility database by submitting your test results:

```bash
# Generate hardware report
python3 debug_system.py report > my_macbook_report.json

# Submit via community portal (coming soon)
```

## Advanced Usage

### Multiple Boot Systems

You can dual-boot Thyme OS with macOS:

1. **Partition Drive**: Keep macOS partition, install Thyme OS on second partition
2. **Boot Selection**: Hold Option (⌥) key during boot to choose OS
3. **GRUB Integration**: GRUB can detect and boot macOS

### Performance Tuning

#### **CPU Governor**:
```bash
# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

#### **Memory Management**:
```bash
# Monitor memory usage
watch -n 1 free -h

# Configure swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

### Development Environment

Thyme OS can be used for development:

```bash
# Install development tools
sudo apt install build-essential git python3-dev nodejs npm

# Modern editors
sudo apt install code  # VS Code
sudo apt install vim-gtk3  # Vim with GUI
```

## Frequently Asked Questions

### **Q: Will this void my MacBook warranty?**
**A:** These MacBooks are from 2006-2009, so warranties expired long ago.

### **Q: Can I go back to macOS?**
**A:** Yes, if you dual-boot. If you replace macOS entirely, you'd need to reinstall macOS from recovery media.

### **Q: Why can't I just use regular Linux?**
**A:** Old MacBooks have 32-bit EFI firmware that can't boot standard 64-bit Linux LiveUSBs. Thyme OS solves this with specialized bootloaders.

### **Q: How is this different from other Linux distributions?**
**A:** Thyme OS includes:
- 32-bit EFI bootstrap solutions
- MacBook-specific hardware fixes
- Sleep/wake problem solutions
- Thermal management optimizations
- Memory management for old hardware

### **Q: Can I install this on newer MacBooks?**
**A:** MacBooks from 2010+ can run standard Linux distributions. Thyme OS is specifically for 2006-2009 models.

### **Q: What desktop environments are available?**
**A:** Default is XFCE (lightweight). You can install MATE, Cinnamon, or others, but XFCE is recommended for performance.

### **Q: Will all my MacBook hardware work?**
**A:** Most hardware works:
- ✅ Wi-Fi, Ethernet, Bluetooth
- ✅ Audio (speakers, headphones, microphone)  
- ✅ Video (built-in display, external monitors)
- ✅ Trackpad, keyboard, function keys
- ✅ USB ports, SD card slot
- ⚠️ Some very old models may have limited 3D graphics

### **Q: How much RAM do I need?**
**A:** Thyme OS runs on 1GB but 2GB+ is recommended. It's optimized for the 2-4GB typically found in these MacBooks.

### **Q: Can I upgrade my old MacBook?**
**A:** 
- **RAM**: Usually upgradeable to 4GB or more
- **Storage**: SSD upgrade highly recommended
- **Wi-Fi**: May be upgradeable to newer standards

---

🍃 **Welcome to Thyme OS - giving your old MacBook new life!**

*For technical support, development info, or to contribute, see DEVELOPER_GUIDE.md*