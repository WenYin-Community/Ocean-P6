#!/usr/bin/env bash
#
# Ocean-P6 SDDM theme installer.
# Installs the theme system-wide into /usr/share/sddm/themes/Ocean-P6.
#
# Usage: sudo ./install.sh

set -euo pipefail
umask 022

readonly THEME_ID="Ocean-P6"
readonly THEME_ROOT="/usr/share/sddm/themes"
readonly THEME_DIR="$THEME_ROOT/$THEME_ID"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

readonly REQUIRED_FILES=(
    Main.qml
    Login.qml
    KeyboardButton.qml
    SessionButton.qml
    Background.qml
    theme.conf
    metadata.desktop
    preview.png
)

readonly REQUIRED_DIRS=(
    components
    assets
    faces
)

usage() {
    cat <<EOF
Usage: sudo ./install.sh

Installs the $THEME_ID SDDM theme to:
  $THEME_DIR

The script preserves an existing theme.conf.user, does not change the
current SDDM theme, and does not restart SDDM.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root." >&2
    echo "Run it with: sudo $0" >&2
    exit 1
fi

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo "Error: missing theme file: $SCRIPT_DIR/$file" >&2
        exit 1
    fi
done

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        echo "Error: missing theme directory: $SCRIPT_DIR/$dir" >&2
        exit 1
    fi
done

echo "Installing $THEME_ID to $THEME_DIR"
install -d -m 755 "$THEME_DIR"

if [ -f "$THEME_DIR/theme.conf.user" ]; then
    echo "Preserving existing theme.conf.user"
fi

for file in "${REQUIRED_FILES[@]}"; do
    cp -f "$SCRIPT_DIR/$file" "$THEME_DIR/$file"
done

for dir in "${REQUIRED_DIRS[@]}"; do
    install -d -m 755 "$THEME_DIR/$dir"
    cp -a "$SCRIPT_DIR/$dir/." "$THEME_DIR/$dir/"
done

chown -R root:root "$THEME_DIR"
chmod -R u=rwX,go=rX "$THEME_DIR"

echo
echo "Installed."
echo
echo "Preview before selecting it:"
echo "  sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
echo "  QT_QUICK_BACKEND=software sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
echo
echo "To activate it, use System Settings -> Colors & Themes -> Login Screen,"
echo "or set [Theme] Current=$THEME_ID in /etc/sddm.conf.d/kde_settings.conf."
echo "The current theme was not modified and SDDM was not restarted."
