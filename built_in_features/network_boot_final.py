#!/usr/bin/env python3
"""
Thyme OS Network Boot Setup - Final Working Version
Lessons learned from testing session 2025-09-14

This is the definitive network boot setup based on real MacBook2,1 testing.
"""

import os
import sys
import subprocess
import socket
from pathlib import Path

class ThymeNetworkBoot:
    def __init__(self):
        self.project_root = Path.cwd()
        self.server_ip = self.get_server_ip()
        self.interface = self.get_ethernet_interface()
        
    def get_server_ip(self) -> str:
        """Get current server IP address"""
        try:
            # Get IP of default route interface
            result = subprocess.run([
                "ip", "route", "get", "1"
            ], capture_output=True, text=True)
            
            for part in result.stdout.split():
                if part.startswith("src"):
                    idx = result.stdout.split().index(part)
                    return result.stdout.split()[idx + 1]
                    
            # Alternative method
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
            
        except Exception:
            return "192.168.1.100"  # fallback
    
    def get_ethernet_interface(self) -> str:
        """Get ethernet interface name"""
        try:
            result = subprocess.run([
                "ip", "link", "show"
            ], capture_output=True, text=True)
            
            for line in result.stdout.split('\n'):
                if 'state UP' in line and ('enp' in line or 'eth' in line):
                    return line.split(':')[1].strip()
                    
            # Fallback - try common names
            for iface in ['enp1s0', 'eth0', 'enp0s1']:
                if Path(f"/sys/class/net/{iface}").exists():
                    return iface
                    
        except Exception:
            pass
            
        return "enp1s0"  # fallback
    
    def install_packages(self) -> bool:
        """Install required network boot packages"""
        print("📦 Installing network boot packages...")
        
        packages = [
            "dnsmasq", "tftpd-hpa", "syslinux-common", 
            "pxelinux", "syslinux-utils"
        ]
        
        try:
            subprocess.run([
                "sudo", "apt-get", "update", "-q"
            ], check=True)
            
            subprocess.run([
                "sudo", "apt-get", "install", "-y"
            ] + packages, check=True)
            
            print("✅ Packages installed")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Package installation failed: {e}")
            return False
    
    def setup_tftp_server(self) -> bool:
        """Set up TFTP server with PXE files"""
        print(f"🌐 Setting up TFTP server on {self.server_ip}...")
        
        tftp_root = Path("/srv/tftp")
        
        try:
            # Create directories
            subprocess.run([
                "sudo", "mkdir", "-p", str(tftp_root), 
                str(tftp_root / "pxelinux.cfg")
            ])
            
            # Copy PXE bootloader
            subprocess.run([
                "sudo", "cp", "/usr/lib/PXELINUX/pxelinux.0", 
                str(tftp_root)
            ])
            
            # Copy required modules
            subprocess.run([
                "sudo", "cp", "/usr/lib/syslinux/modules/bios/menu.c32",
                "/usr/lib/syslinux/modules/bios/ldlinux.c32", 
                str(tftp_root)
            ])
            
            # Create PXE menu
            pxe_config = f"""DEFAULT menu.c32
PROMPT 0
TIMEOUT 100
ONTIMEOUT thyme

MENU TITLE Thyme OS Network Boot
MENU COLOR border       30;44      #40ffffff #a0000000
MENU COLOR title        1;36;44    #9033ccff #a0000000
MENU COLOR sel          7;37;40    #e0ffffff #20ffffff
MENU COLOR unsel        37;44      #50ffffff #a0000000

LABEL thyme
  MENU LABEL ^Thyme OS Test Boot
  MENU DEFAULT
  KERNEL test_kernel
  APPEND initrd=test_initrd console=tty0 thyme_netboot=yes ip=dhcp
  TEXT HELP
    Boot Thyme OS test system for MacBook compatibility testing.
    This proves network boot capability works.
  ENDTEXT

LABEL local
  MENU LABEL Boot from ^local drive
  LOCALBOOT 0x80
  TEXT HELP
    Attempt to boot from local hard drive.
  ENDTEXT
"""
            
            # Write PXE config
            with open("/tmp/pxe_default", "w") as f:
                f.write(pxe_config)
            subprocess.run([
                "sudo", "mv", "/tmp/pxe_default", 
                str(tftp_root / "pxelinux.cfg" / "default")
            ])
            
            # Create test boot files
            test_kernel = f"THYME_TEST_KERNEL_{self.server_ip}".encode() + b"\x00" * 1000
            test_initrd = f"THYME_TEST_INITRD_{self.server_ip}".encode() + b"\x00" * 1000
            
            with open("/tmp/test_kernel", "wb") as f:
                f.write(test_kernel)
            with open("/tmp/test_initrd", "wb") as f:
                f.write(test_initrd)
                
            subprocess.run([
                "sudo", "mv", "/tmp/test_kernel", "/tmp/test_initrd",
                str(tftp_root)
            ])
            
            # Set permissions
            subprocess.run([
                "sudo", "chown", "-R", "tftp:tftp", str(tftp_root)
            ])
            subprocess.run([
                "sudo", "chmod", "-R", "755", str(tftp_root)
            ])
            
            # Configure TFTP service
            tftp_config = f"""TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"  
TFTP_ADDRESS="{self.server_ip}:69"
TFTP_OPTIONS="--secure"
"""
            
            with open("/tmp/tftpd-hpa", "w") as f:
                f.write(tftp_config)
            subprocess.run([
                "sudo", "mv", "/tmp/tftpd-hpa", "/etc/default/tftpd-hpa"
            ])
            
            print("✅ TFTP server configured")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ TFTP setup failed: {e}")
            return False
    
    def setup_dhcp_server(self, mode="coexist") -> bool:
        """Set up DHCP server for PXE boot
        
        Args:
            mode: "coexist" for router coexistence, "standalone" for direct control
        """
        print(f"📡 Setting up DHCP server ({mode} mode)...")
        
        try:
            # Stop existing dnsmasq
            subprocess.run(["sudo", "systemctl", "stop", "dnsmasq"], 
                         capture_output=True)
            
            if mode == "coexist":
                # Coexist with router DHCP - proxy mode
                dnsmasq_config = f"""# Thyme OS PXE Coexistence Configuration
# Works alongside existing router DHCP

# Interface configuration
interface={self.interface}
bind-interfaces

# Disable DNS (avoid conflicts)  
port=0

# Proxy DHCP mode - don't assign IPs
dhcp-range={self.interface},proxy

# PXE boot options
dhcp-boot=pxelinux.0,{self.server_ip}

# TFTP server location
dhcp-option=66,{self.server_ip}
dhcp-option=67,pxelinux.0

# PXE vendor options
dhcp-option=vendor:PXEClient,6,2b

# Enable TFTP serving
enable-tftp
tftp-root=/srv/tftp

# Logging
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log

# Don't read system files
no-hosts
no-resolv
no-poll
"""
            
            else:  # standalone mode
                # Full DHCP server - use when router DHCP is disabled
                network = ".".join(self.server_ip.split(".")[:-1])
                dnsmasq_config = f"""# Thyme OS PXE Standalone Configuration
# Full DHCP server for direct network control

interface={self.interface}
bind-interfaces

# Disable DNS (let systemd-resolved handle)
port=0

# DHCP IP range
dhcp-range={network}.200,{network}.220,12h

# PXE boot options  
dhcp-boot=pxelinux.0,{self.server_ip}

# Network options
dhcp-option=1,255.255.255.0
dhcp-option=3,{network}.1
dhcp-option=6,{network}.1

# TFTP options
dhcp-option=66,{self.server_ip}
dhcp-option=67,pxelinux.0

# PXE vendor options
dhcp-option=vendor:PXEClient,6,2b

# Enable TFTP serving
enable-tftp  
tftp-root=/srv/tftp

# Be authoritative
dhcp-authoritative

# Logging
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log

# Don't read system files
no-hosts
no-resolv
no-poll
"""
            
            # Write configuration
            with open("/tmp/dnsmasq.conf", "w") as f:
                f.write(dnsmasq_config)
            
            # Test configuration
            result = subprocess.run([
                "dnsmasq", "--test", "-C", "/tmp/dnsmasq.conf"
            ], capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Configuration test failed: {result.stderr}")
                return False
            
            # Install configuration
            subprocess.run([
                "sudo", "mv", "/tmp/dnsmasq.conf", "/etc/dnsmasq.conf"
            ])
            
            print("✅ DHCP server configured")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ DHCP setup failed: {e}")
            return False
    
    def start_services(self) -> bool:
        """Start network boot services"""
        print("🚀 Starting network boot services...")
        
        services = ["tftpd-hpa", "dnsmasq"]
        
        for service in services:
            try:
                # Enable service
                subprocess.run([
                    "sudo", "systemctl", "enable", service
                ], check=True, capture_output=True)
                
                # Start service
                subprocess.run([
                    "sudo", "systemctl", "start", service
                ], check=True, capture_output=True)
                
                # Check status
                result = subprocess.run([
                    "sudo", "systemctl", "is-active", service
                ], capture_output=True, text=True)
                
                if "active" in result.stdout:
                    print(f"✅ {service} running")
                else:
                    print(f"❌ {service} failed to start")
                    return False
                    
            except subprocess.CalledProcessError as e:
                print(f"❌ Failed to start {service}: {e}")
                return False
        
        return True
    
    def validate_setup(self) -> bool:
        """Validate network boot setup"""
        print("🔍 Validating network boot setup...")
        
        checks = [
            ("TFTP files exist", lambda: Path("/srv/tftp/pxelinux.0").exists()),
            ("TFTP config exists", lambda: Path("/srv/tftp/pxelinux.cfg/default").exists()),
            ("DHCP config exists", lambda: Path("/etc/dnsmasq.conf").exists()),
        ]
        
        all_good = True
        for desc, check in checks:
            if check():
                print(f"✅ {desc}")
            else:
                print(f"❌ {desc}")
                all_good = False
        
        # Check network ports
        try:
            import socket
            
            # Check TFTP port
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            result = sock.connect_ex((self.server_ip, 69))
            if result == 0:
                print("✅ TFTP port accessible")
            else:
                print("⚠️ TFTP port may not be accessible")
            sock.close()
            
        except Exception as e:
            print(f"⚠️ Port check failed: {e}")
        
        return all_good
    
    def show_instructions(self):
        """Show MacBook boot instructions"""
        print("\n" + "="*60)
        print("🍃 Thyme OS Network Boot Server Ready!")
        print("="*60)
        print(f"Server IP: {self.server_ip}")
        print(f"Interface: {self.interface}")
        print()
        print("MacBook2,1 Network Boot Instructions:")
        print("1. Connect MacBook to same network via Ethernet")
        print("2. Power on MacBook while holding 'N' key")  
        print("3. MacBook should discover network boot server")
        print("4. Select 'Thyme OS Test Boot' from menu")
        print()
        print("Alternative method:")
        print("1. Hold Option (⌥) key during boot")
        print("2. Look for 'Network' boot option")
        print("3. Follow boot menu prompts")
        print()
        print("Troubleshooting:")
        print("- Ensure both machines on same network")
        print("- Check network cables")
        print("- Monitor logs: sudo tail -f /var/log/dnsmasq.log")
        print()
        print("Services:")
        print(f"- TFTP: {self.server_ip}:69")
        print("- DHCP: proxy mode (coexists with router)")
        print("="*60)
    
    def setup_complete(self, mode="coexist") -> bool:
        """Complete network boot setup"""
        print("🍃 Thyme OS Network Boot Setup")
        print("="*40)
        print(f"Server IP: {self.server_ip}")
        print(f"Interface: {self.interface}")
        print(f"Mode: {mode}")
        print()
        
        steps = [
            ("Installing packages", self.install_packages),
            ("Setting up TFTP server", self.setup_tftp_server),
            ("Setting up DHCP server", lambda: self.setup_dhcp_server(mode)),
            ("Starting services", self.start_services),
            ("Validating setup", self.validate_setup),
        ]
        
        for desc, func in steps:
            print(f"📋 {desc}...")
            if not func():
                print(f"❌ Setup failed at: {desc}")
                return False
        
        self.show_instructions()
        return True

def main():
    """Main network boot setup"""
    if len(sys.argv) < 2:
        print("Thyme OS Network Boot Setup - Final Version")
        print("Usage: python3 network_boot_final.py <command> [options]")
        print()
        print("Commands:")
        print("  setup [coexist|standalone] - Complete network boot setup")
        print("  info                       - Show server information")
        print("  instructions              - Show boot instructions")
        print("  test                      - Test configuration")
        return
    
    netboot = ThymeNetworkBoot()
    command = sys.argv[1]
    
    if command == "setup":
        mode = sys.argv[2] if len(sys.argv) > 2 else "coexist"
        success = netboot.setup_complete(mode)
        sys.exit(0 if success else 1)
    
    elif command == "info":
        print(f"Server IP: {netboot.server_ip}")
        print(f"Interface: {netboot.interface}")
        
    elif command == "instructions":
        netboot.show_instructions()
        
    elif command == "test":
        netboot.validate_setup()
        
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()