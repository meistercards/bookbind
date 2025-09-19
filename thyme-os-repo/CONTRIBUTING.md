# Contributing to Thyme OS

Thank you for your interest in contributing to Thyme OS! This project exists to make Linux accessible on vintage MacBooks, and we welcome contributions from the community.

## 🎯 Ways to Contribute

### 🖥️ Hardware Testing
The most valuable contribution is testing Thyme OS on different MacBook models:

1. **Download** the latest release ISO
2. **Test** using our bootstrap methods on your MacBook
3. **Report** results using our hardware testing tools
4. **Earn recognition** in our community hardware database

```bash
# Submit hardware compatibility report
python3 community/hardware_database/submit_report.py
```

### 🔧 Code Contributions

#### Bootstrap Methods
- Improve existing installation methods
- Create new bootstrap approaches
- Optimize for specific MacBook models

#### System Fixes
- Sleep/wake improvements
- Thermal management enhancements
- Hardware driver optimizations

#### Tools and Utilities
- Hardware detection improvements
- Diagnostic tool enhancements
- Community support utilities

### 📚 Documentation
- Installation guides for new hardware
- Troubleshooting documentation
- User experience improvements
- Translation to other languages

### 🐛 Bug Reports
- System issues and crashes  
- Hardware compatibility problems
- Installation failures
- Performance issues

## 🏗️ Development Workflow

### 1. Fork and Clone
```bash
git clone https://github.com/YOUR_USERNAME/thyme-os.git
cd thyme-os
git remote add upstream https://github.com/thyme-os/thyme-os.git
```

### 2. Create Feature Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
# or  
git checkout -b hardware/macbook-model
```

### 3. Development Environment
```bash
# Install development dependencies
pip3 install -r build/requirements.txt

# Run tests before making changes
python3 testing/automated/run_all_tests.py

# Build and test your changes
python3 build/build_system.py create --hardware your_target
```

### 4. Testing
- **Unit Tests**: Test individual components
- **Integration Tests**: Test bootstrap methods
- **Hardware Tests**: Test on real MacBooks when possible

```bash
# Run specific test suite
python3 testing/bootstrap_validation/bootstrap_validator.py

# Hardware-specific testing
python3 testing/hardware_tests/macbook_tests.py
```

### 5. Submit Pull Request
1. **Push** your feature branch to your fork
2. **Create** pull request from your branch to `develop`
3. **Fill out** the pull request template completely
4. **Wait** for automated testing to complete
5. **Respond** to code review feedback

## 📋 Code Guidelines

### Python Code Style
- Follow **PEP 8** style guidelines
- Use **type hints** for function parameters and returns
- Include **docstrings** for all functions and classes
- Use **meaningful variable names**

### Bash Scripts
- Use **`#!/bin/bash`** shebang
- Include **error handling** (`set -e`)
- Use **quotes** around variable expansions
- Include **usage information** and help text

### Documentation
- Update relevant **README** files
- Include **inline comments** for complex logic
- Write **clear commit messages**
- Update **compatibility matrix** for hardware changes

## 🧪 Hardware Testing Program

### Testing Hardware
If you have a MacBook that can run Thyme OS, we need your help:

#### Before Testing
1. **Backup** your MacBook completely  
2. **Verify** you can restore to original state
3. **Have recovery media** ready (macOS install discs/USB)
4. **Document** your hardware specifications

#### During Testing  
1. **Test all applicable** bootstrap methods
2. **Document** success/failure of each method
3. **Test system functionality** (sleep/wake, thermal, Wi-Fi)
4. **Record** any issues or performance problems

#### After Testing
1. **Submit** hardware report using our tools
2. **Share** results with community via GitHub Discussions
3. **Help** other users with similar hardware
4. **Earn** community recognition badges

### Hardware You Can Help Test
- **MacBook1,1** (2006) - Core Duo, need initial testing
- **MacBook3,1** (2007) - Core 2 Duo T7300, need verification  
- **MacBook4,1** (2008) - Core 2 Duo T8300, need verification
- **MacBookPro1,1** (2006) - Core Duo, need initial testing
- **MacBookPro2,1** (2006) - Core 2 Duo T7600, need verification
- **MacBookPro3,1** (2007) - Core 2 Duo T7500, need verification

## 🏆 Recognition Program

### Community Badges
- **🥇 Pioneer**: First successful installation on untested MacBook model
- **🔬 Validator**: Confirm compatibility on previously tested model  
- **🛠️ Contributor**: Submit code fixes, improvements, or features
- **📚 Documenter**: Significant documentation contributions
- **🏅 Tester**: Active participation in hardware testing program

### How Recognition Works
1. **Automated** - Some badges awarded automatically via GitHub Actions
2. **Community** - Recognition through GitHub Discussions and issues
3. **Profile** - Badges displayed in contributor profiles and README
4. **Special** - Major contributors featured in project documentation

## 📞 Getting Help

### Community Support
- **💬 [GitHub Discussions](https://github.com/thyme-os/thyme-os/discussions)** - Ask questions, share experiences
- **🐛 [Issues](https://github.com/thyme-os/thyme-os/issues)** - Report bugs, request features
- **📖 [Wiki](https://github.com/thyme-os/thyme-os/wiki)** - Community knowledge base

### Development Help
- **🔧 Development Issues** - Use "help wanted" label for guidance
- **📋 Good First Issues** - Look for "good first issue" label
- **👥 Mentorship** - Ask for help in Discussions with "development" tag

## ⚡ Code Review Process

### What We Look For
1. **Functionality** - Does the code work as intended?
2. **Compatibility** - Will this work across different MacBook models?
3. **Testing** - Are there appropriate tests?
4. **Documentation** - Is the change properly documented?
5. **Style** - Does code follow project conventions?

### Review Timeline
- **Automated testing** runs immediately on PR submission
- **Initial review** within 2-3 days (project volunteers)
- **Hardware testing** may take longer depending on hardware availability
- **Multiple review rounds** may be needed for complex changes

### After Approval
- **Merge to develop** branch for integration testing
- **Release integration** in next version planning
- **Hardware validation** on target MacBook models
- **Community announcement** for significant features

## 📜 Legal and Licensing

### Code Contributions
By contributing to Thyme OS, you agree that your contributions will be licensed under the **GPL-3.0** license.

### Hardware Information
Hardware compatibility reports and system information shared with the project help improve Thyme OS for everyone. This information may be included in our public compatibility database.

### Trademark Considerations  
- **Apple**, **MacBook**, **macOS** are trademarks of Apple Inc.
- **Linux** is a trademark of Linus Torvalds
- **Mint** Linux components retain Linux Mint team licensing

---

## 🍃 Welcome to the Thyme OS Community!

Whether you're contributing code, testing hardware, writing documentation, or helping other users, your involvement makes Thyme OS better for everyone with a vintage MacBook.

**Questions?** Start a discussion in [GitHub Discussions](https://github.com/thyme-os/thyme-os/discussions)

**Ready to contribute?** Check out our [good first issues](https://github.com/thyme-os/thyme-os/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22)

---

*Thank you for helping preserve and extend the life of vintage MacBook hardware!*
