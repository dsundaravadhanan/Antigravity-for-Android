# Antigravity for Android v1.1.1

### What's Changed in v1.1.1
- **Visual Walkthrough & Asset Gallery**: Added full 4-stage mobile screenshots (`assets/`) covering Termux installation, Google OAuth onboarding, Web GUI chat workspace, and agent settings.
- **Enhanced Termux Installation (`install.sh`)**:
  - Integrated `termux-wake-lock` to keep the background language engine alive and prevent Android battery suspension.
  - Added dual-stack `/etc/hosts` configuration (`127.0.0.1` and `::1 localhost`) for instant local socket binding.
  - Added `NODE_OPTIONS="--dns-result-order=ipv4first"` for zero network latency on mobile carrier data.
- **Troubleshooting & FAQ Guide in `README.md`**:
  - Added fixes for `agy: command not found` ($PATH resolution).
  - Added steps for `localhost:4400` connection issues.
  - Added Android Phantom Process Killer workarounds.
  - Added browser OAuth bridge testing and IPv6 delay fixes.
- **Repository URL Standardization**: Aligned all script and documentation references to the canonical `Antigravity-for-Android` repository.

### Release Assets
- `assets/01-termux-install.jpg`: Terminal installation screenshot.
- `assets/02-google-signin.jpg`: Google OAuth sign-in onboarding screen.
- `assets/03-web-gui-workspace.jpg`: Antigravity Web GUI workspace screenshot.
- `assets/04-settings-permissions.jpg`: Settings and permissions screenshot.
- `install.sh`: Automated installer and environment optimizer.
- `patch_gui.sh`: Legacy Web GUI patcher.
- `revert_gui.sh`: Universal uninstaller.
