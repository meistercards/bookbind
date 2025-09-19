# Thyme OS Plymouth Theme Installation

## Install Plymouth Theme

1. Copy theme files:
   ```bash
   sudo cp -r plymouth_theme /usr/share/plymouth/themes/thyme
   ```

2. Create background and logo images:
   ```bash
   # Convert SVG wallpaper to PNG background
   inkscape wallpaper.svg --export-png=/usr/share/plymouth/themes/thyme/background.png
   
   # Convert logo to PNG
   inkscape ../logo.svg --export-png=/usr/share/plymouth/themes/thyme/logo.png
   ```

3. Set as default theme:
   ```bash
   sudo plymouth-set-default-theme thyme
   sudo update-initramfs -u
   ```

## Features
- Animated Thyme OS logo with gentle pulsing
- MacBook-themed boot messages
- Progress bar in thyme green
- Smooth animations optimized for older hardware
