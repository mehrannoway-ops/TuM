#!/bin/bash
# ==============================================================================
# Mehtunnel Installer
# ==============================================================================

# مسیر نصب
INSTALL_PATH="/usr/local/bin/mehtunnel.sh"

# دانلود فایل اصلی
echo "[•] Downloading Mehtunnel script..."
curl -fsSL "https://raw.githubusercontent.com/mehrannoway-ops/TuM/main/mehtunnel.sh" -o "$INSTALL_PATH"

# مجوز اجرایی
chmod +x "$INSTALL_PATH"

# اجرا
echo "[•] Launching Mehtunnel..."
"$INSTALL_PATH"
