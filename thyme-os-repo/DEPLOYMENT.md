# Thyme OS Repository Deployment Guide

## Repository Setup Steps

### 1. Create GitHub Repository
```bash
# On GitHub.com:
# 1. Create new repository: thyme-os/thyme-os
# 2. Set visibility: Public
# 3. Initialize with README: No (we have our own)
# 4. Add .gitignore: None (we have custom ignore rules)
# 5. Add license: None (we have GPL-3.0)
```

### 2. Clone and Setup Local Repository
```bash
git clone https://github.com/thyme-os/thyme-os.git
cd thyme-os

# Copy repository structure
cp -r ../thyme-os-repo/* .
cp -r ../thyme-os-repo/.github .

# Initialize git if needed
git init
git remote add origin https://github.com/thyme-os/thyme-os.git
```

### 3. Migrate Development Files
```bash
# Run the migration script to copy development files
./migrate_files.sh

# Or manually copy files according to the structure:
# Development file -> Repository location
```

### 4. Initial Commit and Push
```bash
git add .
git commit -m "🎉 Initial Thyme OS repository setup

- Complete repository structure
- GitHub Actions workflows
- Issue and PR templates
- Documentation framework
- Bootstrap method organization
- Community tools structure"

git branch -M main
git push -u origin main
```

### 5. Create Development Branch
```bash
git checkout -b develop
git push -u origin develop

# Set develop as default branch for PRs in GitHub settings
```

### 6. Configure Repository Settings

#### Branch Protection Rules
```yaml
Branch: main
- Require pull request reviews before merging
- Require status checks to pass before merging
- Require branches to be up to date before merging  
- Include administrators in restrictions

Branch: develop  
- Require status checks to pass before merging
- Allow force pushes (for development flexibility)
```

#### GitHub Features
- **Issues**: Enable with templates
- **Discussions**: Enable with categories:
  - General
  - Hardware Testing
  - Development
  - Support
  - Security
- **Projects**: Create "Thyme OS Development" project board
- **Wiki**: Enable for community documentation
- **Security**: Enable security advisories

#### Labels
Create these labels for issue management:
- `bug` (red) - Something isn't working
- `enhancement` (blue) - New feature or request
- `hardware` (purple) - Hardware compatibility related
- `bootstrap` (orange) - Bootstrap method related
- `documentation` (green) - Improvements or additions to documentation
- `good first issue` (light green) - Good for newcomers
- `help wanted` (yellow) - Extra attention is needed
- `priority-high` (dark red) - High priority item
- `community` (light blue) - Community tools and resources
- `testing` (pink) - Testing related

### 7. Setup GitHub Pages
```bash
# In repository settings:
# - Pages -> Source: GitHub Actions
# - Custom domain: thyme-os.org (if available)

# The release workflow will automatically deploy the website
```

### 8. Configure Secrets and Environment Variables
```bash
# Repository Settings -> Secrets and Variables -> Actions

# Add these secrets:
# - GITHUB_TOKEN: Automatically provided by GitHub
# - GPG_PRIVATE_KEY: For signing releases (optional)
# - DEPLOY_KEY: For additional deployment access (if needed)
```

### 9. Create Initial Release
```bash
# Create and push release tag
git tag -a v0.1.0-alpha -m "Thyme OS Alpha Release

Initial release with:
- Bootstrap method framework
- MacBook2,1 hardware profile
- Basic build system
- Community tools structure"

git push origin v0.1.0-alpha

# This will trigger the release workflow
```

### 10. Community Setup

#### GitHub Discussions Categories
- **General**: General discussion about Thyme OS
- **Hardware Testing**: Share hardware compatibility results
- **Development**: Development discussion and coordination
- **Support**: Help and troubleshooting
- **Security**: Security-related discussions (public, non-sensitive)

#### Project Boards
Create GitHub Project with columns:
- **Backlog**: Future features and improvements
- **In Progress**: Currently being worked on
- **Testing**: Awaiting hardware testing
- **Ready for Release**: Completed and tested
- **Released**: Available in latest release

#### Initial Issues
Create these initial issues to guide development:
1. "MacBook1,1 Hardware Testing" (hardware, help wanted)
2. "Improve SSD Swap Documentation" (documentation, good first issue)
3. "Create Network Installation Guide" (documentation)
4. "Add MacBookPro3,1 Support" (hardware, enhancement)

## Post-Setup Tasks

### Documentation
1. **Update README** with current download links
2. **Create installation guides** for each bootstrap method  
3. **Update hardware matrix** with tested models
4. **Write contributing guide** specific to current development status

### Community Building
1. **Announce in relevant forums** (Reddit r/VintageApple, etc.)
2. **Create social media presence** (Twitter, Mastodon)
3. **Reach out to MacBook communities** for testing volunteers
4. **Document early adopter experiences**

### Development Priorities
1. **Complete bootstrap method testing** on real hardware
2. **Expand hardware compatibility** to additional MacBook models
3. **Improve automated testing** for CI/CD workflows
4. **Create user-friendly installation tools**

### Release Management
1. **Create release schedule** (monthly/quarterly)
2. **Setup changelog automation** 
3. **Plan hardware testing coordination** for releases
4. **Develop update/upgrade system** for installed systems

---

## Repository Maintenance

### Regular Tasks
- **Weekly**: Review new issues and PRs
- **Monthly**: Update hardware compatibility matrix
- **Quarterly**: Major release planning and testing
- **Annually**: Review and update documentation

### Community Engagement
- **Respond** to issues within 48 hours
- **Review** PRs within 72 hours  
- **Update** community on development progress monthly
- **Recognize** contributors in release notes

### Security
- **Monitor** security advisories for dependencies
- **Update** base Linux Mint regularly
- **Review** community-submitted code carefully
- **Maintain** responsible disclosure process

---

*This deployment guide ensures a professional, community-ready repository launch for Thyme OS.*
