#!/bin/bash
# Thyme OS Desktop Assets Deployment Script

set -e

echo "🍃 Deploying Thyme OS Desktop Assets..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Don't run this script as root. It will use sudo when needed."
   exit 1
fi

# Wallpaper
echo "📷 Installing wallpaper..."
sudo mkdir -p /usr/share/backgrounds/thyme
sudo cp wallpaper.svg /usr/share/backgrounds/thyme/
# Convert to PNG for compatibility
if command -v inkscape &> /dev/null; then
    inkscape wallpaper.svg --export-png=/tmp/thyme_wallpaper.png --export-width=1920 --export-height=1080
    sudo cp /tmp/thyme_wallpaper.png /usr/share/backgrounds/thyme/wallpaper.png
    rm /tmp/thyme_wallpaper.png
fi

# GTK Theme Colors
echo "🎨 Installing GTK theme colors..."
sudo mkdir -p /usr/share/themes/Thyme/gtk-3.0
sudo cp gtk_colors.conf /usr/share/themes/Thyme/

# Icon Theme
echo "🖼️  Installing icon theme..."
sudo mkdir -p /usr/share/icons/Thyme
sudo cp -r icon_theme/* /usr/share/icons/Thyme/
sudo gtk-update-icon-cache /usr/share/icons/Thyme/ 2>/dev/null || true

# Plymouth Theme (if plymouth is installed)
if command -v plymouth &> /dev/null; then
    echo "🚀 Installing Plymouth boot theme..."
    sudo cp -r plymouth_theme /usr/share/plymouth/themes/thyme
    
    # Convert logo for plymouth
    if command -v inkscape &> /dev/null; then
        inkscape ../logo.svg --export-png=/tmp/thyme_logo.png --export-width=120 --export-height=120
        sudo cp /tmp/thyme_logo.png /usr/share/plymouth/themes/thyme/logo.png
        rm /tmp/thyme_logo.png
    fi
    
    echo "ℹ️  To activate Plymouth theme, run:"
    echo "   sudo plymouth-set-default-theme thyme"
    echo "   sudo update-initramfs -u"
fi

# Set wallpaper (GNOME/Unity)
if command -v gsettings &> /dev/null; then
    echo "🖥️  Setting wallpaper (GNOME)..."
    gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/thyme/wallpaper.png"
fi

# Set wallpaper (XFCE)  
if command -v xfconf-query &> /dev/null; then
    echo "🖥️  Setting wallpaper (XFCE)..."
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "/usr/share/backgrounds/thyme/wallpaper.png"
fi

echo "✅ Thyme OS desktop assets deployed successfully!"
echo ""
echo "🎯 What was installed:"
echo "   • Thyme OS wallpaper (/usr/share/backgrounds/thyme/)"
echo "   • GTK theme colors (/usr/share/themes/Thyme/)"
echo "   • Icon theme structure (/usr/share/icons/Thyme/)"
echo "   • Plymouth boot theme (/usr/share/plymouth/themes/thyme/)"
echo ""
echo "🔄 You may need to log out and back in to see all changes."
