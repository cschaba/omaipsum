#!/bin/bash

# Installs omaipsum into Omarchy. Safe to re-run.
#
# One rule governs this script: it writes nothing outside omaipsum's own
# directories. The symlink into ~/.config/omarchy/plugins is ours to make, and
# registration goes through omarchy's own commands because they own
# ~/.config/omarchy/shell.json. Anything that would change a file you own — the
# keybinding in ~/.config/hypr/bindings.lua — is printed for you to paste. A
# plugin that rewrites your compositor config is one you have to trust twice.

set -euo pipefail

# Resolved rather than assumed, so the script works from any working directory
# and the link points at this checkout rather than at $PWD. -P because the
# comparison below is against readlink -f, which resolves all the way down.
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ID="cschaba.omaipsum"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BINDINGS="$HOME/.config/hypr/bindings.lua"

# The widget publishes its own IpcHandler under this target (BarWidget.qml,
# `ipcTarget`), and Ui/Panel.qml gives that handler open/close/toggle. So the
# pulldown is addressed by name, not through the shell's generic surface toggle.
TOGGLE_CMD="omarchy-shell cschaba.omaipsum.widget toggle"
# I for ipsum, and free in Omarchy's own defaults at the time of writing.
CHORD="SUPER + ALT + I"

say() { echo "  $*"; }

# --- 1. the plugin directory ------------------------------------------------
#
# A symlink and not a copy: the checkout stays the only copy of the code, so an
# edit is live after a shell restart, with nothing to reinstall in between.

if [[ -L $PLUGIN_DIR ]]; then
  # readlink -f on a link into thin air still prints a path and can fail, and
  # neither is worth stopping for — it gets replaced either way.
  current="$(readlink -f "$PLUGIN_DIR" 2>/dev/null || true)"
  if [[ $current == "$SOURCE_DIR" ]]; then
    say "✓ already linked from $SOURCE_DIR"
  else
    # Replacing a symlink destroys nothing — whatever it pointed at is still
    # there. Name it anyway, in case it was another checkout being tested.
    ln -sfn "$SOURCE_DIR" "$PLUGIN_DIR"
    say "✓ relinked $PLUGIN_DIR → $SOURCE_DIR (was ${current:-a broken link})"
  fi
elif [[ -e $PLUGIN_DIR ]]; then
  # A real directory means somebody's files: an `omarchy plugin add` clone, or
  # an older copy-install. Deleting it is not this script's call to make.
  say "! $PLUGIN_DIR exists and is not a link to this checkout."
  say "  omaipsum is installed there some other way, and its files are not"
  say "  mine to delete. Remove that copy with"
  say "      omarchy plugin remove $PLUGIN_ID"
  say "  or move it aside, then re-run this script."
  exit 1
else
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  ln -sfn "$SOURCE_DIR" "$PLUGIN_DIR"
  say "✓ linked $SOURCE_DIR → $PLUGIN_DIR"
fi

# --- 2. registration, through omarchy's own commands ------------------------

if ! command -v omarchy >/dev/null 2>&1; then
  echo
  say "! omarchy was not found on PATH."
  say "  omaipsum is an Omarchy plugin, and registering it means writing"
  say "  ~/.config/omarchy/shell.json — a file omarchy owns and this script"
  say "  will not touch itself. Install Omarchy, then re-run:"
  say "      $SOURCE_DIR/install.sh"
  exit 1
fi

# The shell keeps its own list of what is installed, and a directory that
# appeared after it started is not on it. Quiet and best-effort: with no shell
# running there is nobody to tell, and that is not a failure.
omarchy-shell -q shell rescanPlugins >/dev/null 2>&1 || true

# ...and then wait for it to land. rescanPlugins is fire-and-forget: the IPC
# call returns when the shell accepts it, not when the scan has finished, so
# enabling on the next line asks about a plugin the shell has not read yet and
# is told it does not exist. It takes about 50ms here. omarchy-plugin-add has
# the same problem and solves it the same way, polling the plugin list rather
# than sleeping a guessed amount.
#
# This is what made a fresh install fail while reporting nothing: `-q` returns
# success even when the call does nothing, so a rescan that never happened and
# one that worked look identical from here.
plugin_known() {
  omarchy plugin list 2>/dev/null | grep -qF "$PLUGIN_ID"
}

wait_for_discovery() {
  local attempt
  for (( attempt = 0; attempt < 40; attempt++ )); do
    plugin_known && return 0
    sleep 0.05
  done
  return 1
}

# Where the widget goes, asked once rather than assumed. This mirrors
# select_bar_widget_placement() in omarchy-plugin-add: the manifest's own
# defaultSection is the pre-selection, and a non-interactive run or a missing
# gum takes that default silently — install.sh has to stay scriptable.
PLACEMENT=()
choose_placement() {
  local default_section chosen
  [[ -t 0 && -t 1 ]] || return 0
  command -v gum >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  default_section=$(jq -r '.barWidget.defaultSection // "center"' "$SOURCE_DIR/manifest.json" 2>/dev/null) || return 0
  chosen=$(printf '%s\n' left center right |
    gum choose --header="Place omaipsum in which bar section?" --selected "$default_section") || return 0
  [[ -n $chosen ]] || return 0
  PLACEMENT=(--section "$chosen")
}

register() {
  # `plugin enable` places a bar widget as well as enabling it, and leaves an
  # entry that is already in the layout where it is.
  omarchy plugin enable "$PLUGIN_ID" "${PLACEMENT[@]}" || return 1
  # `bar put` is the unattended verb: it leaves a widget that is already on the
  # bar exactly where its owner put it, and waits out a shell that is still
  # starting up. After a successful enable it changes nothing — which is what
  # makes a second run of this script produce one widget rather than two.
  omarchy bar put "$PLUGIN_ID" || return 1
}

if ! wait_for_discovery; then
  say "! the shell has not picked omaipsum up."
  say "  That is what happens when omarchy-shell is not running — start it, or"
  say "  restart it, and this script will work on the next run:"
  say "      omarchy restart shell"
  say "      $SOURCE_DIR/install.sh"
  exit 1
fi

choose_placement

if register_output="$(register 2>&1)"; then
  say "✓ enabled, and the widget is on the bar"
else
  say "! omarchy could not register omaipsum. It said:"
  printf '%s\n' "$register_output" | sed 's/^/      /'
  say "  Run these once the shell is up:"
  say "      omarchy plugin enable $PLUGIN_ID"
  say "      omarchy bar put $PLUGIN_ID"
fi

# --- 3. the runtime dependency ----------------------------------------------
#
# wl-clipboard provides wl-copy, which is how the panel copies. Everything else
# works without it; the copy button is the whole point, so say so plainly.
# Installing it is not ours to do — no package manager runs from here.

if command -v wl-copy >/dev/null 2>&1; then
  say "✓ wl-copy found"
else
  say "! wl-copy is missing, so copying will not work. It comes from the"
  say "  wl-clipboard package. Install it yourself, for example with:"
  say "      omarchy pkg add wl-clipboard"
fi

# --- 4. the keybinding, which is yours to add -------------------------------

echo
if [[ -f $BINDINGS ]] && grep -qF "$TOGGLE_CMD" "$BINDINGS"; then
  say "✓ a keybinding for the pulldown is already in $BINDINGS"
else
  say "The pulldown opens from its bar icon. If you want a key for it too —"
  say "one step, in a file that belongs to you — add this to $BINDINGS:"
  echo
  echo "    -- omaipsum"
  echo "    o.bind(\"$CHORD\", \"Lorem ipsum\", \"$TOGGLE_CMD\")"
  echo
  say "then reload with:  hyprctl reload"

  # Only your own overrides are checked, not Hyprland's whole binding list.
  # The binding is optional and there is no omaipsum config to move the chord
  # to, so a conflict here is worth a sentence, not an interrogation — and the
  # file you are about to paste into is the one place a surprise would live.
  if [[ -f $BINDINGS ]] && grep -qF "\"$CHORD\"" "$BINDINGS"; then
    echo
    say "! $CHORD already appears in that file. Pick a free chord in the line"
    say "  above; Omarchy's own bindings are listed by:"
    say "      omarchy menu keybindings --print"
  fi
fi

# --- 5. what happens next ---------------------------------------------------

echo
say "omaipsum installed. Restart the shell to load it:"
say "    omarchy restart shell"
say "omarchy-shell reads a plugin's QML once at startup and keeps it for the"
say "life of the process, so a restart is also how you see any later edit."
