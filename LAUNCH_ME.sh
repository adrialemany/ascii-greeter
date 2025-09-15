#!/usr/bin/env bash
set -euo pipefail

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WELCOME_SCRIPT="$SCRIPT_DIR/scripts/.ascii-welcome.sh"
LAUNCH_SCRIPT="$SCRIPT_DIR/scripts/launch-terminal-maximized.sh"

BASHRC="${HOME}/.bashrc"
MARKER_START="# >>> ascii-greeter block (auto-added) >>>"
MARKER_END="# <<< ascii-greeter block (auto-added) <<<"

info "Hi! This is your ASCII Installer Setup Helper."
info "The necessary code to see your drawings will be automatically added to file .bashrc."
info "Read each question and answer depending on how much custamization you want."
info "All important info is in the README file. Briefly, what you need to know is:"
info "1. To add new drawings, just add them to the root of the repo."
info "2. If there are no drawings, just a message will be shown."
info "3. To modify the info or text shown in terminal, modify scripts/.ascii-welcome.sh"
info "4. To find interesting ASCII drawings, visit:"
info "https://www.asciiart.eu/"
info "5. Any suggestions? Email me to al426695@uji.es!"


if grep -Fq "$MARKER_START" "$BASHRC"; then
  info "ascii-greeter block already present in ~/.bashrc. It will not be duplicated."
else
  info "Adding ascii-greeter block to the end of ~/.bashrc…"
  {
    echo ""
    echo "$MARKER_START"

    echo "if [ -t 1 ] && [ -z \"\$NO_ASCII_ART\" ]; then"
    echo "    \"$WELCOME_SCRIPT\""
    echo "fi"
    echo ""
    echo "echo \"\""
    echo "echo \"\""
    echo "echo \"\""
    echo "$MARKER_END"
  } >> "$BASHRC"
  ok "Block added to ~/.bashrc."
fi

if [[ ! -f "$WELCOME_SCRIPT" ]]; then
  warn "Did not find $WELCOME_SCRIPT. Create that file if you want the ASCII greeting."
fi

echo

read -r -p 'Do you want to open the terminal always in full screen mode with Ctrl + Alt + T? (yes/no) ' ANSWER
ANSWER="$(echo "${ANSWER:-}" | tr '[:upper:]' '[:lower:]')"

case "$ANSWER" in
  y|yes)
    info "Setting up custom shortcut 'Maximized Terminal' with Ctrl+Alt+T…"

    if ! command -v gsettings >/dev/null 2>&1; then
      error "gsettings is not available. Are you on GNOME? Aborting."
      exit 1
    fi

    if [[ ! -f "$LAUNCH_SCRIPT" ]]; then
      error "Script not found: $LAUNCH_SCRIPT"
      error "Make sure it exists and re-run this installer."
      exit 1
    fi

    chmod +x "$LAUNCH_SCRIPT" || true

    if gsettings writable org.gnome.settings-daemon.plugins.media-keys terminal >/dev/null 2>&1; then
      CURRENT_BINDING="$(gsettings get org.gnome.settings-daemon.plugins.media-keys terminal || true)"
      info "Current default shortcut (terminal): ${CURRENT_BINDING:-unknown}"
      gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "[]"
      ok "Default shortcut disabled."
    else
      warn "Couldn't access the 'terminal' key under media-keys. Continuing anyway."
    fi

    BASE_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
    CUSTOM_LIST_KEY="custom-keybindings"
    CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/maximized-terminal/"

    EXISTING_LIST="$(gsettings get ${BASE_SCHEMA} ${CUSTOM_LIST_KEY} 2>/dev/null || echo "[]")"

    if [[ "$EXISTING_LIST" != *"$CUSTOM_PATH"* ]]; then
      if [[ "$EXISTING_LIST" == "[]" || "$EXISTING_LIST" == "@as []" ]]; then
        NEW_LIST="['$CUSTOM_PATH']"
      else
        NEW_LIST="${EXISTING_LIST%]*}, '$CUSTOM_PATH']"
      fi
      gsettings set ${BASE_SCHEMA} ${CUSTOM_LIST_KEY} "$NEW_LIST"
      info "Added to the Custom Shortcuts list."
    else
      info "The custom shortcut was already listed."
    fi

    CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" name "Maximized Terminal"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" command "$LAUNCH_SCRIPT"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" binding "<Primary><Alt>T"

    ok "Custom shortcut configured."

    echo
    info "Summary:"
    echo "  - ~/.bashrc updated (with absolute path to the repo)."
    echo "  - Default shortcut (Launchers → Terminal) disabled."
    echo "  - New shortcut (Custom Shortcuts → Maximized Terminal) with Ctrl+Alt+T."
    echo "  - Command: $LAUNCH_SCRIPT"
    ;;

  n|no|*)
    info "Keyboard shortcuts will not be modified. Only ~/.bashrc was updated."
    ;;
esac

echo

read -r -p 'Do you want a maximized terminal to open automatically at login? (yes/no) ' AUTOSTART_ANSWER
AUTOSTART_ANSWER="$(echo "${AUTOSTART_ANSWER:-}" | tr '[:upper:]' '[:lower:]')"

case "$AUTOSTART_ANSWER" in
  y|yes)
    if [[ ! -f "$LAUNCH_SCRIPT" ]]; then
      error "Script not found: $LAUNCH_SCRIPT"
      error "Required for autostart. Cancelling this part."
    else
      chmod +x "$LAUNCH_SCRIPT" || true
      AUTOSTART_DIR="$HOME/.config/autostart"
      AUTOSTART_DESKTOP="$AUTOSTART_DIR/maximized-terminal-on-startup.desktop"

      mkdir -p "$AUTOSTART_DIR"

      cat > "$AUTOSTART_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Maximized Terminal
Comment=Open a maximized terminal on login
Exec=$LAUNCH_SCRIPT
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;Unity;
# You can add an optional delay (seconds):
# X-GNOME-Autostart-Delay=2
EOF
      ok "Autostart configured: $AUTOSTART_DESKTOP"
      info "A maximized terminal will open on the next login."
    fi
    ;;
  n|no|*)
    info "Autostart not configured."
    ;;
esac

ok "Process completed."

