# BookBind (Thyme OS)

**📖 Linux installer for old MacBooks**

BookBind is a specialized installer that helps you install Linux on old MacBooks (2006-2009) that can't boot from standard LiveUSB drives.

## Quick Start

### Do You Need BookBind?

**BookBind is for you if:**
- You have a MacBook from 2006-2009
- Your MacBook can't boot from Linux LiveUSB drives
- macOS is too slow or no longer supported
- You want to give your old MacBook new life

**You probably don't need BookBind if:**
- Your MacBook is from 2010 or newer
- You can already boot Linux LiveUSBs successfully
- Your MacBook runs macOS well

## Supported Hardware

### Fully Tested & Supported ✅
- **MacBookPro2,2** (2006, Core 2 Duo)

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

## Installation

### Requirements
- A working Linux system (the "host")
- USB-to-SATA adapter
- Target SSD/hard drive for the MacBook
- The MacBook you want to install Linux on

### Method: USB-to-SATA Installation

**Best for:** Any situation where you have a working Linux system

**Time:** 30-45 minutes

**Steps:**
1. Boot your host Linux system
2. Connect target SSD via USB-to-SATA adapter
3. Download and run BookBind:
   ```bash
   wget https://raw.githubusercontent.com/meistercards/bookbind/main/bookbind.sh
   chmod +x bookbind.sh
   sudo ./bookbind.sh
   ```
4. Follow the interactive prompts
5. Install the SSD in your MacBook
6. Boot and complete first-time setup

### What BookBind Does

1. **Smart System Copy**: Copies your current Linux system while excluding bloatware
2. **MacBook Optimization**: Applies memory and thermal optimizations for old hardware
3. **32-bit EFI Bootloader**: Installs GRUB with 32-bit EFI support
4. **First-Boot Setup**: Creates user account and configures the system

## Troubleshooting

### MacBook Won't Boot
- Ensure 32-bit EFI bootloader is properly installed
- Try holding Alt/Option during boot to see boot options
- Check that SSD is properly connected

### System Runs Slowly
- BookBind includes memory optimizations for 2-4GB systems
- Disable unnecessary services in first-boot setup
- Consider adding more RAM if possible

### Installation Fails
- Ensure target drive has enough space (minimum 8GB)
- Check USB-to-SATA adapter compatibility
- Verify host system has required packages

## Contributing

Found a bug or want to add support for your MacBook model? Open an issue or submit a pull request!

## License

MIT License - feel free to use and modify.

---

*Made with ❤️ for keeping old MacBooks useful*
