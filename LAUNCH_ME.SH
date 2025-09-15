#!/usr/bin/env bash
set -euo pipefail

# --- Utilidades ---
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# Directorio absoluto donde está este script (raíz del repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Rutas absolutas a los scripts que usaremos
WELCOME_SCRIPT="$SCRIPT_DIR/scripts/.ascii-welcome.sh"
LAUNCH_SCRIPT="$SCRIPT_DIR/scripts/launch-terminal-maximized.sh"

# --- 1) Añadir bloque al final de ~/.bashrc con rutas ABSOLUTAS ---
BASHRC="${HOME}/.bashrc"
MARKER_START="# >>> ascii-greeter block (auto-added) >>>"
MARKER_END="# <<< ascii-greeter block (auto-added) <<<"

if grep -Fq "$MARKER_START" "$BASHRC"; then
  info "Bloque ascii-greeter ya presente en ~/.bashrc. No se duplicará."
else
  info "Añadiendo bloque ascii-greeter al final de ~/.bashrc…"
  {
    echo ""
    echo "$MARKER_START"
    # Escribimos la ruta ABSOLUTA ya expandida
    echo "if [ -t 1 ] && [ -z \"\$NO_ASCII_ART\" ]; then"
    echo "    \"$WELCOME_SCRIPT\""
    echo "fi"
    echo ""
    echo "echo \"\""
    echo "echo \"\""
    echo "echo \"\""
    echo "$MARKER_END"
  } >> "$BASHRC"
  ok "Bloque añadido a ~/.bashrc."
fi

# Aviso si falta el script de bienvenida (no bloquea la instalación)
if [[ ! -f "$WELCOME_SCRIPT" ]]; then
  warn "No se encontró $WELCOME_SCRIPT. Crea ese archivo si quieres el saludo ASCII."
fi

echo

# --- 2) Preguntar sobre el atajo maximizado ---
read -r -p 'Do you want to open the terminal always in full screen mode with Ctrl + Alt + T? (yes/no) ' ANSWER
ANSWER="$(echo "${ANSWER:-}" | tr '[:upper:]' '[:lower:]')"

case "$ANSWER" in
  y|yes)
    info "Configurando atajo personalizado 'Maximized Terminal' con Ctrl+Alt+T…"

    # Verificaciones básicas
    if ! command -v gsettings >/dev/null 2>&1; then
      error "gsettings no está disponible. ¿Estás en GNOME? Abortando."
      exit 1
    fi

    if [[ ! -f "$LAUNCH_SCRIPT" ]]; then
      error "No se encontró el script: $LAUNCH_SCRIPT"
      error "Asegúrate de que exista y vuelve a ejecutar este instalador."
      exit 1
    fi

    chmod +x "$LAUNCH_SCRIPT" || true

    # 2.a) Deshabilitar atajo por defecto de 'Launchers → Terminal'
    # Clave: org.gnome.settings-daemon.plugins.media-keys terminal
    if gsettings writable org.gnome.settings-daemon.plugins.media-keys terminal >/dev/null 2>&1; then
      CURRENT_BINDING="$(gsettings get org.gnome.settings-daemon.plugins.media-keys terminal || true)"
      info "Atajo por defecto actual (terminal): ${CURRENT_BINDING:-desconocido}"
      gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "[]"
      ok "Atajo por defecto deshabilitado."
    else
      warn "No se pudo acceder a la clave 'terminal' de media-keys. Continuando igualmente."
    fi

    # 2.b) Crear/actualizar atajo en Custom Shortcuts
    BASE_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
    CUSTOM_LIST_KEY="custom-keybindings"
    CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/maximized-terminal/"

    # Obtener lista actual de custom keybindings
    EXISTING_LIST="$(gsettings get ${BASE_SCHEMA} ${CUSTOM_LIST_KEY} 2>/dev/null || echo "[]")"

    # Añadir nuestro path si no está ya
    if [[ "$EXISTING_LIST" != *"$CUSTOM_PATH"* ]]; then
      if [[ "$EXISTING_LIST" == "[]" || "$EXISTING_LIST" == "@as []" ]]; then
        NEW_LIST="['$CUSTOM_PATH']"
      else
        NEW_LIST="${EXISTING_LIST%]*}, '$CUSTOM_PATH']"
      fi
      gsettings set ${BASE_SCHEMA} ${CUSTOM_LIST_KEY} "$NEW_LIST"
      info "Añadido a la lista de Custom Shortcuts."
    else
      info "El atajo personalizado ya estaba listado."
    fi

    # Establecer nombre, comando y combinación
    CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" name "Maximized Terminal"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" command "$LAUNCH_SCRIPT"
    gsettings set "${CUSTOM_SCHEMA}:${CUSTOM_PATH}" binding "<Primary><Alt>T"

    ok "Atajo personalizado configurado."

    echo
    info "Resumen:"
    echo "  - ~/.bashrc actualizado (con ruta absoluta al repo)."
    echo "  - Atajo por defecto (Launchers → Terminal) deshabilitado."
    echo "  - Nuevo atajo (Custom Shortcuts → Maximized Terminal) con Ctrl+Alt+T."
    echo "  - Comando: $LAUNCH_SCRIPT"
    ;;

  n|no|*)
    info "No se modificarán los atajos de teclado. Solo se actualizó ~/.bashrc."
    ;;
esac

ok "Proceso completado."
