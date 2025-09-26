# Security Policy

## Supported Versions

Thyme OS follows a rolling release model with security updates applied to the current stable release.

| Version | Supported |
| ------- | --------- |
| Latest Release | ✅ |
| Development Branch | ⚠️ Testing only |
| Previous Releases | ❌ |

## Reporting a Vulnerability

### 🔒 Private Reporting (Recommended)
For security vulnerabilities, please use GitHub's private vulnerability reporting:

1. Go to [Security Advisories](https://github.com/thyme-os/thyme-os/security/advisories)
2. Click "Report a vulnerability"
3. Fill out the vulnerability report form
4. We'll respond within 48 hours

### 📧 Email Reporting
For highly sensitive issues, email: security@thyme-os.org

### ⚠️ What NOT to Report Publicly
- Authentication bypasses
- Privilege escalation vulnerabilities  
- Remote code execution flaws
- Information disclosure issues
- Any issue that could compromise user systems

### ✅ What CAN be Reported Publicly
- General bugs without security implications
- Hardware compatibility issues
- Documentation errors
- Build system problems
- Performance issues

## Security Considerations

### MacBook-Specific Risks
- **EFI Security**: 32-bit EFI systems have inherent limitations
- **Legacy Hardware**: Old systems may lack modern security features
- **Driver Security**: Older drivers may have known vulnerabilities

### Thyme OS Mitigations
- **Minimal Attack Surface**: Lightweight system reduces vulnerability exposure
- **Regular Updates**: Security patches from Ubuntu/Mint upstream
- **Community Review**: Open source code allows security auditing
- **Bootstrap Security**: Multiple installation methods reduce single points of failure

## Response Process

### Initial Response (0-48 hours)
- Acknowledge receipt of vulnerability report
- Initial assessment of severity and impact
- Assignment to security team member

### Investigation (2-14 days)
- Reproduce and validate the vulnerability
- Assess impact on MacBook hardware and users
- Develop fix or mitigation strategy
- Coordinate with upstream projects if needed

### Resolution (7-30 days)
- Implement and test security fix
- Prepare security advisory
- Plan coordinated disclosure
- Release updated packages/ISO

### Public Disclosure
- **CVE Assignment** - Request CVE if applicable
- **Security Advisory** - Published on GitHub Security Advisories
- **Release Notes** - Security fixes noted in release documentation
- **Community Notification** - Announced via GitHub Discussions

## Security Best Practices

### For Users
- **Download** Thyme OS only from official GitHub releases
- **Verify** checksums and signatures when available
- **Keep Updated** - Apply security updates promptly
- **Backup** - Maintain backups before installing

### For Contributors
- **Code Review** - All changes reviewed for security implications
- **Input Validation** - Validate all user inputs and system data
- **Principle of Least Privilege** - Run with minimal required permissions
- **Secure Defaults** - Default configurations should be secure

### For Hardware Testing
- **Isolated Testing** - Use dedicated test hardware when possible
- **Network Isolation** - Test in isolated network environments
- **Data Protection** - Don't test with sensitive personal data
- **Recovery Planning** - Ensure you can restore systems after testing

## Known Security Considerations

### MacBook Hardware Limitations
- **32-bit EFI** - Limited security features compared to modern UEFI
- **Legacy BIOS** - Some models may fall back to BIOS mode
- **Firmware Updates** - MacBook firmware may have unpatched vulnerabilities
- **Hardware Age** - Physical security limitations of aging hardware

### Thyme OS Specific
- **Bootstrap Methods** - Some installation methods require elevated privileges
- **System Modifications** - Sleep/wake fixes modify system behavior
- **Driver Installation** - Hardware-specific drivers may need kernel-level access
- **Network Installation** - PXE boot method has inherent network security considerations

## Supported MacBook Security Features

### Working Security Features
- **User Account Security** - Standard Linux user/group permissions
- **Filesystem Security** - Standard ext4 permissions and encryption support
- **Network Security** - Firewall and network access controls
- **Package Security** - APT package verification and signatures

### Limited/Unavailable Features
- **Secure Boot** - Not supported on 32-bit EFI MacBooks
- **TPM** - Not available on vintage MacBook hardware
- **Hardware Encryption** - Limited by MacBook hardware capabilities
- **UEFI Security** - Limited to 32-bit EFI capabilities

## Incident Response

### If You Discover a Security Issue
1. **Stop** - Don't continue testing that could cause harm
2. **Document** - Record steps to reproduce (privately)
3. **Report** - Use private vulnerability reporting channels
4. **Wait** - Don't disclose publicly until coordinated release

### Community Security Alerts
Security alerts will be posted via:
- **GitHub Security Advisories**  
- **GitHub Discussions** (Security category)
- **Release Notes** for security updates
- **Website Updates** for critical issues

## Contact Information

- **Private Vulnerabilities**: GitHub Security Advisories (preferred)
- **Security Email**: security@thyme-os.org
- **General Security Questions**: GitHub Discussions with "security" tag
- **Urgent Issues**: Tag security team members in private reports

---

*Security is a community effort. Thank you for helping keep Thyme OS safe for all MacBook users.*
