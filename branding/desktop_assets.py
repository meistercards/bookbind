#!/usr/bin/env python3
"""
Thyme OS Desktop Assets Generator
Creates desktop theme components for the Thyme OS branding
"""

import os
import xml.etree.ElementTree as ET
from pathlib import Path

class ThymeDesktopAssets:
    def __init__(self):
        self.colors = {
            'thyme_green': '#2E7D32',
            'deep_green': '#1B5E20', 
            'light_green': '#66BB6A',
            'sage_green': '#81C784',
            'pale_green': '#A5D6A7',
            'stem_brown': '#4E342E'
        }
        
        self.assets_dir = Path("desktop_assets")
        self.assets_dir.mkdir(exist_ok=True)
    
    def create_wallpaper_svg(self):
        """Create Thyme OS desktop wallpaper"""
        svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1920" height="1080" viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">
  <!-- Gradient background -->
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="70%">
      <stop offset="0%" style="stop-color:{self.colors['pale_green']};stop-opacity:0.3"/>
      <stop offset="70%" style="stop-color:{self.colors['thyme_green']};stop-opacity:0.1"/>
      <stop offset="100%" style="stop-color:{self.colors['deep_green']};stop-opacity:0.05"/>
    </radialGradient>
    
    <pattern id="subtle_texture" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
      <rect width="100" height="100" fill="none"/>
      <circle cx="50" cy="50" r="1" fill="{self.colors['sage_green']}" opacity="0.1"/>
    </pattern>
  </defs>
  
  <!-- Base background -->
  <rect width="1920" height="1080" fill="{self.colors['deep_green']}"/>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#subtle_texture)"/>
  
  <!-- Large decorative thyme sprigs -->
  <g opacity="0.15">
    <!-- Bottom left sprig -->
    <g transform="translate(200, 800) scale(3)">
      <rect x="-2" y="-50" width="4" height="80" fill="{self.colors['stem_brown']}" rx="2"/>
      <ellipse cx="-12" cy="-35" rx="8" ry="4" fill="{self.colors['light_green']}" transform="rotate(-25)"/>
      <ellipse cx="15" cy="-25" rx="8" ry="4" fill="{self.colors['light_green']}" transform="rotate(30)"/>
      <ellipse cx="-10" cy="-15" rx="8" ry="4" fill="{self.colors['sage_green']}" transform="rotate(-20)"/>
      <ellipse cx="12" cy="-5" rx="8" ry="4" fill="{self.colors['sage_green']}" transform="rotate(25)"/>
    </g>
    
    <!-- Top right sprig -->
    <g transform="translate(1600, 300) scale(2.5) rotate(45)">
      <rect x="-2" y="-40" width="4" height="60" fill="{self.colors['stem_brown']}" rx="2"/>
      <ellipse cx="-10" cy="-25" rx="6" ry="3" fill="{self.colors['light_green']}" transform="rotate(-30)"/>
      <ellipse cx="12" cy="-15" rx="6" ry="3" fill="{self.colors['light_green']}" transform="rotate(25)"/>
      <ellipse cx="-8" cy="-5" rx="6" ry="3" fill="{self.colors['sage_green']}" transform="rotate(-25)"/>
    </g>
  </g>
  
  <!-- Centered Thyme OS logo -->
  <g transform="translate(960, 540)">
    <circle cx="0" cy="0" r="80" fill="{self.colors['thyme_green']}" opacity="0.8"/>
    <circle cx="0" cy="0" r="76" fill="none" stroke="{self.colors['pale_green']}" stroke-width="2"/>
    
    <!-- Thyme sprig -->
    <rect x="-3" y="-50" width="6" height="70" fill="{self.colors['stem_brown']}" rx="3"/>
    <ellipse cx="-15" cy="-35" rx="10" ry="5" fill="{self.colors['light_green']}" transform="rotate(-25)"/>
    <ellipse cx="18" cy="-25" rx="10" ry="5" fill="{self.colors['light_green']}" transform="rotate(30)"/>
    <ellipse cx="-12" cy="-15" rx="10" ry="5" fill="{self.colors['sage_green']}" transform="rotate(-20)"/>
    <ellipse cx="15" cy="-5" rx="10" ry="5" fill="{self.colors['sage_green']}" transform="rotate(25)"/>
    <ellipse cx="-10" cy="5" rx="10" ry="5" fill="{self.colors['pale_green']}" transform="rotate(-15)"/>
    <ellipse cx="12" cy="15" rx="10" ry="5" fill="{self.colors['pale_green']}" transform="rotate(20)"/>
    
    <!-- Subtle Apple reference -->
    <circle cx="25" cy="-40" r="12" fill="{self.colors['sage_green']}" opacity="0.6"/>
    <circle cx="30" cy="-36" r="6" fill="{self.colors['thyme_green']}"/>
  </g>
  
  <!-- Bottom text -->
  <text x="960" y="720" font-family="Arial, sans-serif" font-size="36" font-weight="300" 
        fill="{self.colors['pale_green']}" text-anchor="middle" opacity="0.7">
    THYME OS
  </text>
  <text x="960" y="760" font-family="Arial, sans-serif" font-size="18" font-weight="300" 
        fill="{self.colors['sage_green']}" text-anchor="middle" opacity="0.6">
    Linux for MacBooks
  </text>
</svg>'''
        
        with open(self.assets_dir / "wallpaper.svg", "w") as f:
            f.write(svg_content)
        
        print("✅ Created wallpaper.svg")
    
    def create_plymouth_theme(self):
        """Create Plymouth boot splash theme"""
        
        # Plymouth theme configuration
        theme_config = f'''[Plymouth Theme]
Name=Thyme OS
Description=Thyme OS boot splash with MacBook compatibility branding
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/thyme
ScriptFile=/usr/share/plymouth/themes/thyme/thyme.script
'''
        
        # Plymouth script for animated boot
        plymouth_script = f'''# Thyme OS Plymouth Boot Theme
# Animated thyme sprig with progress indicator

# Colors
thyme_green = Colour({self.colors['thyme_green']});
sage_green = Colour({self.colors['sage_green']});
pale_green = Colour({self.colors['pale_green']});

# Screen setup
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

# Background
background.image = Image("background.png");
background.sprite = Sprite(background.image);
background.sprite.SetPosition(0, 0);

# Logo animation
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(screen_width / 2 - logo.image.GetWidth() / 2,
                       screen_height / 2 - logo.image.GetHeight() / 2 - 50);

# Progress bar
progress_box.image = Image.Text("", 0, 0, 0);
progress_box.sprite = Sprite(progress_box.image);
progress_box.sprite.SetPosition(screen_width / 2 - 150, screen_height / 2 + 100);

# Thyme OS text
title.image = Image.Text("Thyme OS", 24, 1, 1, 1);
title.sprite = Sprite(title.image);
title.sprite.SetPosition(screen_width / 2 - title.image.GetWidth() / 2,
                        screen_height / 2 + 50);

subtitle.image = Image.Text("Reviving your MacBook", 14, 0.8, 0.8, 0.8);
subtitle.sprite = Sprite(subtitle.image);
subtitle.sprite.SetPosition(screen_width / 2 - subtitle.image.GetWidth() / 2,
                           screen_height / 2 + 80);

# Progress callback
fun progress_callback(duration, progress) {{
    # Animate progress bar
    progress_width = progress * 300;
    progress_image = Image.Text("", progress_width, 4, thyme_green.GetRed(), 
                               thyme_green.GetGreen(), thyme_green.GetBlue());
    progress_box.sprite.SetImage(progress_image);
    
    # Gentle logo pulse based on progress
    scale = 1.0 + Math.Sin(duration * 2) * 0.05;
    logo.sprite.SetScale(scale, scale);
}}

Plymouth.SetUpdateFunction(progress_callback);

# Message display for boot messages
message_sprite = Sprite();
message_sprite.SetPosition(50, screen_height - 50);

fun message_callback(text) {{
    my_image = Image.Text(text, 12, 1, 1, 1);
    message_sprite.SetImage(my_image);
}}

Plymouth.SetDisplayMessageFunction(message_callback);
'''
        
        # Create plymouth theme directory
        plymouth_dir = self.assets_dir / "plymouth_theme"
        plymouth_dir.mkdir(exist_ok=True)
        
        with open(plymouth_dir / "thyme.plymouth", "w") as f:
            f.write(theme_config)
        
        with open(plymouth_dir / "thyme.script", "w") as f:
            f.write(plymouth_script)
        
        # Installation instructions
        install_instructions = """# Thyme OS Plymouth Theme Installation

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
"""
        
        with open(plymouth_dir / "INSTALL.md", "w") as f:
            f.write(install_instructions)
        
        print("✅ Created Plymouth boot theme")
    
    def create_gtk_theme_colors(self):
        """Create GTK theme color definitions"""
        
        gtk_colors = f'''# Thyme OS GTK Theme Colors
# Use these in GTK theme development

[Colors]
# Primary Thyme palette
thyme_green = {self.colors['thyme_green']}
deep_green = {self.colors['deep_green']}
light_green = {self.colors['light_green']}
sage_green = {self.colors['sage_green']}
pale_green = {self.colors['pale_green']}
stem_brown = {self.colors['stem_brown']}

# UI application
bg_color = {self.colors['pale_green']}
fg_color = #2C2C2C
selected_bg_color = {self.colors['thyme_green']}
selected_fg_color = #FFFFFF
base_color = #FFFFFF
text_color = #2C2C2C

# Window elements
headerbar_bg = {self.colors['thyme_green']}
headerbar_fg = #FFFFFF
button_bg = {self.colors['sage_green']}
button_hover_bg = {self.colors['light_green']}

# Links and accents
link_color = {self.colors['deep_green']}
accent_color = {self.colors['thyme_green']}
'''
        
        with open(self.assets_dir / "gtk_colors.conf", "w") as f:
            f.write(gtk_colors)
        
        print("✅ Created GTK theme colors")
    
    def create_icon_theme_index(self):
        """Create icon theme index for Thyme OS icons"""
        
        icon_theme_index = f'''[Icon Theme]
Name=Thyme
Comment=Thyme OS icon theme with MacBook-friendly design
Inherits=Adwaita,gnome,hicolor
Directories=16x16/apps,22x22/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps

[16x16/apps]
Size=16
Context=Applications
Type=Fixed

[22x22/apps]
Size=22
Context=Applications
Type=Fixed

[32x32/apps]
Size=32
Context=Applications
Type=Fixed

[48x48/apps]
Size=48
Context=Applications
Type=Fixed

[64x64/apps]
Size=64
Context=Applications
Type=Fixed

[128x128/apps]
Size=128
Context=Applications
Type=Fixed
'''
        
        icons_dir = self.assets_dir / "icon_theme"
        icons_dir.mkdir(exist_ok=True)
        
        with open(icons_dir / "index.theme", "w") as f:
            f.write(icon_theme_index)
        
        # Create directory structure
        for size in ["16x16", "22x22", "32x32", "48x48", "64x64", "128x128"]:
            (icons_dir / size / "apps").mkdir(parents=True, exist_ok=True)
        
        print("✅ Created icon theme structure")
    
    def create_cursor_theme(self):
        """Create basic cursor theme info"""
        
        cursor_config = '''[Icon Theme]
Name=Thyme Cursors
Comment=Thyme OS cursor theme
Inherits=default

# This would typically include custom cursor files
# For now, inherits from system default with Thyme accent colors
'''
        
        cursor_dir = self.assets_dir / "cursor_theme"
        cursor_dir.mkdir(exist_ok=True)
        
        with open(cursor_dir / "index.theme", "w") as f:
            f.write(cursor_config)
        
        print("✅ Created cursor theme config")
    
    def create_sound_theme(self):
        """Create sound theme definition"""
        
        sound_config = '''# Thyme OS Sound Theme
# Defines audio branding for system events

[Sound Theme]
Name=Thyme
DisplayName=Thyme OS Sounds
Comment=Nature-inspired system sounds for Thyme OS
Directories=

# Sound mappings would include:
# - Subtle organic sounds for notifications
# - MacBook-specific boot/shutdown sounds
# - Gentle, non-intrusive system alerts
# - Optimized for older MacBook speakers
'''
        
        with open(self.assets_dir / "sound_theme.conf", "w") as f:
            f.write(sound_config)
        
        print("✅ Created sound theme config")
    
    def create_deployment_script(self):
        """Create script to deploy all desktop assets"""
        
        deploy_script = '''#!/bin/bash
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
'''
        
        with open(self.assets_dir / "deploy_assets.sh", "w") as f:
            f.write(deploy_script)
        
        os.chmod(self.assets_dir / "deploy_assets.sh", 0o755)
        
        print("✅ Created deployment script")
    
    def generate_all_assets(self):
        """Generate all desktop assets"""
        print("🎨 Generating Thyme OS Desktop Assets...")
        
        self.create_wallpaper_svg()
        self.create_plymouth_theme() 
        self.create_gtk_theme_colors()
        self.create_icon_theme_index()
        self.create_cursor_theme()
        self.create_sound_theme()
        self.create_deployment_script()
        
        print("\n✅ All desktop assets generated in desktop_assets/")
        print("🚀 Run ./desktop_assets/deploy_assets.sh to install")

def main():
    assets = ThymeDesktopAssets()
    assets.generate_all_assets()

if __name__ == "__main__":
    main()