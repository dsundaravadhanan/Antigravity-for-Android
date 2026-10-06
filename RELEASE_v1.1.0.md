# Antigravity Web GUI for Termux v1.1.0

### What's Changed
- **Official Google Native Android Engine Support**: Added full native support for Google's official Android Bionic CLI (`cli_android_arm64`) distributed directly via `https://antigravity.google/cli/install.sh`.
- **Zero Glibc Dependency**: The official installation runs directly on Android Bionic libc without `glibc-repo` or `glibc-runner`.
- **Interactive 1-Step Setup (`install.sh`)**: Interactively checks for official Google `agy` and offers to install it automatically if missing, configured with `export AGY_INSTALL_SKIP_LAUNCH=1`.
- **Automatic Termux PATH Resolution**: Automatically links `$HOME/.local/bin/agy -> $PREFIX/bin/agy` and appends to `~/.bashrc`, resolving the Termux PATH warning on startup.
- **Fixed OAuth Browser Tab Opening**: Bridges `xdg-open` to `termux-open-url` so the Google authentication page automatically opens in a new tab in your Android browser.
- **Universal Dual-Engine Uninstaller (`revert_gui.sh`)**: Pre-checks binary branding before modifying, safely reverting both Wallentx community builds and Official Google native installations without cross-engine contamination.
- **Privacy-Preserving Authentication**: Restricts all token handling strictly to the official `~/.gemini/antigravity-cli/` directory with `chmod 700`/`600` permissions. No external storage or download directories are scanned.
- **Preserved Community Wallentx Methods**: Retained all original glibc-based instructions and options in `README.md` and repository scripts for older devices.

### Release Assets
- `install.sh`: One-line installer and environment setup for official Google Antigravity CLI.
- `patch_gui.sh`: Post-install patcher with dynamic asset repair for legacy Wallentx builds.
- `revert_gui.sh`: Universal uninstaller supporting both official and community installations.
