#!/bin/bash

# Removes omaipsum from Omarchy.
#
# The same rule governs it as install.sh: it touches nothing outside omaipsum's
# own directories. It unregisters through omarchy's own commands, removes the
# symlink install.sh made, and — only when asked — omaipsum's own config and
# state. The keybinding lives in ~/.config/hypr/bindings.lua, which belongs to
# you: install.sh could not add it, so this cannot remove it either. It is
# printed for you to delete.

set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ID="cschaba.omaipsum"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BINDINGS="$HOME/.config/hypr/bindings.lua"
# Neither exists in this version — the widget's settings live in shell.json,
# where `omarchy bar set` keeps them. A later version may create them, and an
# uninstaller that only knows about today's files is one you have to remember
# to update.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omaipsum"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omaipsum"
TOGGLE_CMD="omarchy-shell cschaba.omaipsum.widget toggle"

PURGE=0
while (( $# > 0 )); do
  case "$1" in
  --purge)
    PURGE=1
    shift
    ;;
  -h | --help)
    cat <<'USAGE'
./uninstall.sh [--purge]

  Takes the widget off the bar, disables the plugin and removes the symlink
  in ~/.config/omarchy/plugins. --purge also removes omaipsum's own config
  and state under ~/.config/omaipsum and ~/.local/state/omaipsum.

  Your checkout is never deleted, and no file outside omaipsum's own
  directories is edited — the keybinding is printed for you to remove.
USAGE
    exit 0
    ;;
  *)
    echo "uninstall.sh: unknown option: $1" >&2
    echo "Usage: ./uninstall.sh [--purge]" >&2
    exit 1
    ;;
  esac
done

say() { echo "  $*"; }

removed_something=0
left_behind=0

# --- 1. unregister, through omarchy's own command ---------------------------
#
# First, while the manifest is still somewhere omarchy can read it. `plugin
# disable` is both halves of the job: for a third-party bar widget it drops the
# layout entry and marks the plugin off. There is no `omarchy bar remove` —
# the bar group has put, move and set and nothing that takes a widget away —
# so disable is the whole way back out.

if command -v omarchy >/dev/null 2>&1; then
  if omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1; then
    say "✓ taken off the bar and disabled"
    removed_something=1
  else
    # Either omarchy never knew this id or no shell was listening. Neither is
    # an error here: there is nothing to disable in both cases.
    say "· nothing to disable — omarchy does not know $PLUGIN_ID, or the shell"
    say "  is not running"
  fi
else
  say "! omarchy not found — nothing was unregistered. If you reinstall it, run:"
  say "      omarchy plugin disable $PLUGIN_ID"
fi

# --- 2. the plugin link -----------------------------------------------------

if [[ -L $PLUGIN_DIR ]]; then
  # rm on a symlink removes the link and never what it points at, so the
  # checkout this script is running from stays exactly where it is.
  rm -f "$PLUGIN_DIR"
  say "✓ removed the link at $PLUGIN_DIR"
  removed_something=1
elif [[ -e $PLUGIN_DIR ]]; then
  # A real directory holds somebody's files. install.sh refuses to overwrite
  # one, and this refuses to delete one.
  say "! $PLUGIN_DIR is a real directory, not the link install.sh makes."
  say "  Its contents are not mine to delete. Remove it yourself, or with:"
  say "      omarchy plugin remove $PLUGIN_ID"
  left_behind=1
else
  say "· no plugin link at $PLUGIN_DIR"
fi

# So the running shell forgets the plugin it can no longer find. Best-effort,
# for the same reason as in install.sh.
omarchy-shell -q shell rescanPlugins >/dev/null 2>&1 || true

# --- 3. omaipsum's own config and state, only when asked --------------------

for dir in "$CONFIG_DIR" "$STATE_DIR"; do
  if (( PURGE )); then
    if [[ -d $dir ]]; then
      rm -rf "$dir"
      say "✓ removed $dir"
      removed_something=1
    fi
  elif [[ -e $dir ]]; then
    say "· kept $dir — ./uninstall.sh --purge removes it"
  fi
done

# --- 4. what is left for you, because it was never ours to edit -------------

if [[ -f $BINDINGS ]] && grep -qF "$TOGGLE_CMD" "$BINDINGS"; then
  echo
  say "A keybinding for omaipsum is still in $BINDINGS:"
  grep -nF "$TOGGLE_CMD" "$BINDINGS" | sed 's/^/      /'
  say "Delete that line, and the -- omaipsum comment above it, when convenient,"
  say "then reload with:  hyprctl reload"
  say "omaipsum does not edit your Hyprland config, on the way in or out."
fi

echo
if (( left_behind )); then
  say "omaipsum unregistered, but the directory above is still on disk."
elif (( removed_something )); then
  say "omaipsum removed."
else
  say "omaipsum was not installed — nothing to do."
fi
say "The checkout at $SOURCE_DIR is untouched; ./install.sh puts it back."
