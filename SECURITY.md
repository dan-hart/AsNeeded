# Security Policy

## Scope

This document outlines the security posture of **AsNeeded**, a privacy-first iOS medication tracking app.

## No Secrets Policy

**This repository must never contain:**
- API keys or tokens
- Passwords or credentials
- Private keys (SSH, GPG, signing keys, etc.)
- Environment files with sensitive values (`.env` with secrets)
- Database connection strings with credentials
- App Store Connect credentials or certificates
- Push notification keys (.p8 files)
- Any other sensitive authentication data

If you discover any secrets accidentally committed to this repository, please report it immediately (see below).

## App Security Properties

AsNeeded is designed with privacy and security as core principles:

- **Local-first data**: All health data is stored locally on-device using Core Data
- **No cloud sync**: Health tracking data never leaves your device
- **No data collection**: No user data is collected, stored on servers, or transmitted
- **Minimal permissions**: Only requests permissions essential for functionality
- **No tracking**: No analytics or tracking beyond essential crash reporting
- **App Groups isolation**: Shared data between app and widgets is contained within app sandbox
- **Keychain security**: Sensitive credentials (if any) use iOS Keychain for secure storage
- **Open development practices**: Security measures and policies are documented

### Third-Party Dependencies

- **RevenueCat SDK**: Used for subscription management only. RevenueCat receives anonymized purchase data as required by Apple for in-app purchases. No health data is shared.

## Defense-in-Depth Security

This repository implements 3-layer secret detection:

1. **Pre-commit hook**: Scans staged files for 17+ provider-specific patterns
2. **Pre-push hook**: Catches secrets committed with `--no-verify`
3. **GitHub Actions**: Server-side enforcement with TruffleHog and Gitleaks

### Known Limitations

**Bypass Vectors (Documented):**
- **`--no-verify` flag**: Pre-commit can be bypassed, but pre-push and CI will catch secrets
- **GitHub web interface**: Commits made via github.com bypass client-side hooks; CI provides protection
- **Force push**: History can be rewritten after CI passes; use branch protection rules

**Detection Limitations:**
- **Binary files**: `.xcassets`, images, PDFs, and databases are not scanned for embedded secrets
- **Runtime concatenation**: Secrets assembled at runtime from multiple variables cannot be detected
- **Multi-line splitting**: Secrets split across multiple lines with string concatenation may evade detection
- **Unicode homoglyphs**: While LC_ALL=C helps, sophisticated Unicode attacks may bypass

**Mitigation:**
- Server-side CI scanning (TruffleHog + Gitleaks) provides defense-in-depth
- Regular security audits with `./scripts/scan-repo.sh`
- Branch protection rules recommended for production branches

See `.githooks/` for implementation details.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by:

1. **GitHub Issues**: Open an issue at [github.com/dan-hart/AsNeeded/issues](https://github.com/dan-hart/AsNeeded/issues)
2. **Email**: Contact the maintainer through GitHub

Please include:
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact assessment
- Any suggested remediation

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Resolution**: Depends on severity, typically within 2 weeks for critical issues

## Security Best Practices for Contributors

When contributing to this project:

1. **Never commit secrets, credentials, or API keys**
2. **Run `./scripts/install-hooks.sh`** to set up security hooks before contributing
3. **Use `.gitignore` patterns** for sensitive local files
4. **Review your changes** before committing with `git diff --staged`
5. **Use environment variables** for any configuration that varies between environments
6. **If you accidentally commit sensitive data**, notify the maintainer immediately

### Setting Up Security Hooks

```bash
# One-time setup for contributors
./scripts/install-hooks.sh

# Verify hooks are working
echo "ghp_test123456789012345678901234567890" > test.txt
git add test.txt
git commit -m "test"  # Should be blocked
rm test.txt
```

### Scanning for Secrets

```bash
# Scan repository history
./scripts/scan-repo.sh

# Or use git-secrets directly
git secrets --scan
git secrets --scan-history
```

---

Last updated: 2025-11-29
