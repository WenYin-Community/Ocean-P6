#!/usr/bin/env bash
#
# Ocean-P6 SDDM theme uninstaller.
# Removes the system-wide installation from /usr/share/sddm/themes/Ocean-P6.
#
# Usage: sudo ./uninstall.sh [--yes]

set -euo pipefail

readonly THEME_ID="Ocean-P6"
readonly THEME_ROOT="/usr/share/sddm/themes"
readonly THEME_DIR="$THEME_ROOT/$THEME_ID"

CONFIRM=1

usage() {
    cat <<EOF
Usage: sudo ./uninstall.sh [--yes]

Removes the system-wide installation:
  $THEME_DIR

Options:
  -y, --yes   Do not ask for confirmation.
  -h, --help  Show this help.

The script refuses to remove the theme while it is the current SDDM theme.
It does not modify SDDM configuration and does not restart SDDM.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -y|--yes)
        CONFIRM=0
        ;;
    "")
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "$#" -gt 1 ]; then
    echo "Error: too many arguments." >&2
    usage >&2
    exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root." >&2
    echo "Run it with: sudo $0" >&2
    exit 1
fi

if [ ! -d "$THEME_DIR" ]; then
    echo "Theme is not installed: $THEME_DIR"
    exit 0
fi

# Read the effective value of a key from the SDDM configuration.
# Later configuration files override earlier ones, matching SDDM behavior.
read_setting() {
    local key="$1"
    { cat /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null || true; } | awk -F= -v key="$key" '
        {
            k = $1
            gsub(/^[ \t]+|[ \t]+$/, "", k)
            if (k == key) {
                v = $0
                sub(/^[^=]*=/, "", v)
                gsub(/^[ \t]+|[ \t]+$/, "", v)
                gsub(/^"|"$/, "", v)
                value = v
            }
        }
        END { printf "%s", value }
    '
}

CURRENT_THEME="$(read_setting Current)"
CURRENT_THEME_DIR="$(read_setting ThemeDir)"
CURRENT_THEME_DIR="${CURRENT_THEME_DIR%/}"
if [ -z "$CURRENT_THEME_DIR" ]; then
    CURRENT_THEME_DIR="$THEME_ROOT"
fi

if [ "$CURRENT_THEME" = "$THEME_ID" ] && [ "$CURRENT_THEME_DIR" = "$THEME_ROOT" ]; then
    echo "Refusing to remove the current SDDM theme ($THEME_ID)." >&2
    echo "Switch to another theme first, for example in" >&2
    echo "System Settings -> Colors & Themes -> Login Screen." >&2
    exit 1
fi

if [ "$CONFIRM" -eq 1 ]; then
    echo "This will permanently remove:"
    echo "  $THEME_DIR"
    if [ -f "$THEME_DIR/theme.conf.user" ]; then
        echo "  including theme.conf.user"
    fi
    read -r -p "Continue? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES)
            ;;
        *)
            echo "Cancelled."
            exit 0
            ;;
    esac
else
    echo "Removing $THEME_DIR"
fi

rm -rf -- "$THEME_DIR"

if [ -e "$THEME_DIR" ]; then
    echo "Error: failed to remove $THEME_DIR" >&2
    exit 1
fi

echo "Removed $THEME_DIR"
echo "SDDM configuration was not modified and SDDM was not restarted."
