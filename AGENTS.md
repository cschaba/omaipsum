# Working on omaipsum

Conventions for anyone — human or agent — making changes here, and the single
place that describes them: [CLAUDE.md](CLAUDE.md) is a pointer to this file,
nothing more. The reasoning behind the code is in
[DEVELOPMENT.md](DEVELOPMENT.md).

## Where things stand

**This repository is documentation only. There is no code yet.** `README.md`,
this file, `DEVELOPMENT.md` and `CHANGELOG.md` are all of it, and the changelog
sits at `0.0.0 — Initial setup`. Do not assume a file exists because a document
names one; most of what is described below is the target, not something you can
run today.

What omaipsum is meant to be: an **Omarchy plugin** (Quickshell/QML, loaded by
`omarchy-shell`) — a bar widget that generates funny lorem-ipsum text. The
README fixes the product decisions. Three text variants in the first version,
a UI modelled on [Tiny Ipsum](https://macmenubar.com/tiny-ipsum/), and a count
selector over words, sentences and paragraphs.

The work is broken into thirteen issues across two milestones: `0.1.0 —
generate and copy` gets a widget that produces text and copies it, `0.2.0 —
shipping` adds install, tests, CI, a release script and a README worth reading.

## Where it lives

**Gitea is home.** `origin` is
`ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`, and every change, issue
and pull request goes there first. A GitHub mirror follows once there is a
first working version — that is also when a marketplace listing becomes
relevant, since it needs a public repository.

CI therefore belongs in `.gitea/workflows`. omapass keeps its workflows under
`.github/workflows`; those are a template for the *jobs*, not for the location.

The `tea` CLI on the development machine authenticates as `omarchy-ai`. It
needs write access to `carsten/omaipsum`, or every issue and pull request
command answers `not found`.

## omapass is the reference

`cschaba/omapass` — checked out at `~/Projects/omapass`, symlinked into
`~/.config/omarchy/plugins/cschaba.omapass` — is the same author's finished
Omarchy plugin, and it is where this file and `DEVELOPMENT.md` were copied
from. It is the worked example for everything omaipsum still needs:
`manifest.json`, `install.sh` and `uninstall.sh`, `scripts/release.sh`,
`tests/`, the CI jobs, and the bar-icon-with-a-pulldown shape in
`BarWidget.qml`. Its `DEVELOPMENT.md` holds Quickshell traps that apply here
unchanged.

Copying from it is the point. Copying from it *without reading* is how the
passages below came to describe a password manager: omaipsum handles no
secrets and needs no `pass`, GPG or PAM, but parts of this file still say
otherwise, and `DEVELOPMENT.md` still opens "Notes for working on omapass
itself". Issue #13 tracks the cleanup; until it lands, prefer what the code
does over what a leftover sentence claims.

## One branch per issue

**Work for an issue happens on its own branch, never directly on `main`.**

```bash
git checkout main && git pull
git checkout -b issue/18-folders     # issue/<number>-<short-slug>
```

`main` stays releasable. Half-finished work, an approach that turns out wrong,
a fix waiting on the reporter to confirm — none of it belongs on the branch
other people install from.

Merge to `main` when the change is complete and its tests pass:

```bash
git checkout main
git merge --no-ff issue/18-folders
git branch -d issue/18-folders
```

`--no-ff` keeps the branch visible in the history, so `git log` still shows
which commits belonged to which issue.

Two things stay on `main` directly: a released version's own bookkeeping
(`scripts/release.sh` commits there), and single-commit corrections to
documentation that no issue is tracking.

## One release per fixed issue

`scripts/release.sh patch` after merging. It runs the tests, bumps
`manifest.json`, moves the `CHANGELOG.md` entry, tags and pushes; the tag
publishes the release. Add the changelog entry under `[Unreleased]` as part of
the fix, not afterwards.

## Commits

Authored `Carsten <carsten@s10r.de>`, with a `Co-Authored-By: Claude` trailer
where that applies. Close issues with `Fixes #N` in the body. Say *why* the
change is what it is — the diff already shows what changed.

## Issues

Fix issues opened by the repository owner directly. For anyone else's,
evaluate it and hand back options rather than acting on your own judgement.

## Before you believe a test

**Restart the shell after changing any QML.** `omarchy-shell` loads a plugin's
QML once at startup and keeps it for the life of the process. `rescanPlugins`
is not a substitute: the shell watches `~/.config/omarchy/plugins` with
`inotifywait -r`, which does not follow symlinked directories, so a symlinked
checkout never fires it.

Two more ways a change can look broken when it is not, both from omapass:

**A bar widget must publish its own implicit size.** The bar sizes each slot
from the active item's `implicitWidth`/`implicitHeight`, so a widget root that
does not set them gets a 0×0 slot and renders nothing — no icon, no gap, no
error, no log line. `panels/power/Panel.qml` does it explicitly.

**Errors in a plugin can surface silently.** Omarchy's panel Loader error path
calls `errorString()` as a function, which throws, so the real message is lost.
To find out what a file actually says, load it in a throwaway Quickshell config
*outside* the shell's config root — inside it, Quickshell treats the directory
as a module and sibling types stop resolving, which produces misleading
`X is not a type` errors instead. The recipe is in omapass's `DEVELOPMENT.md`.

And one about the version: **it lives only in `manifest.json`.** Omarchy
requires it there, so a second copy anywhere else could only drift out of step.

## Commands

Nothing here builds, runs or tests yet. What the issues are working towards,
following omapass:

```bash
./install.sh                                  # symlink the checkout into ~/.config/omarchy/plugins/
omarchy restart shell                         # the only reliable reload after a QML edit
omarchy-shell cschaba.omaipsum.widget toggle  # open the bar pulldown
journalctl --user -f | grep omarchy-shell     # where QML errors land
tests/smoke.sh                                # the suite
scripts/release.sh patch --dry-run            # what a release would do
qmllint -I /usr/share/omarchy/shell *.qml     # type checking, locally
```

CI parses QML with `qmlformat` rather than `qmllint`: `qs.Commons` and `qs.Ui`
resolve only inside the Omarchy shell, and older `qmllint` treats an unresolved
import as an error, so it rejects every file regardless of syntax. `qmlformat`
ignores imports and still catches real syntax errors.

## Use the Omarchy API

**Omarchy already does most of this. Look before building.**

Aviod reinventing the wheel!

Where to look first:

| Need | Use |
|------|-----|
| Enable, disable, list, add or remove a plugin | `omarchy plugin …` |
| Put a widget on the bar, move it, set an option | `omarchy bar …` |
| Open, close or toggle a plugin surface | `omarchy-shell shell summon\|hide\|toggle <id> [payload]` |
| Call into a loaded plugin | `omarchy-shell shell call <id> <method> <arg>` |
| A plugin's own IPC | `IpcHandler` with an `ipcTarget`, as `Ui/Panel.qml` does |
| Desktop notification | `omarchy-notification-send` |
| Run something in a terminal | `omarchy-launch-floating-terminal-with-presentation` |
| Reload the shell after a QML change | `omarchy restart shell` |

And in QML, from `qs.Commons` and `qs.Ui`:

| Need | Use |
|------|-----|
| Colours, fonts, spacing, radii | `Color`, `Style`, `Border` — never a literal |
| A bar button with a popup | `Ui/Panel.qml`, `BarIconButton`, `KeyboardPanel` |
| Keyboard handling in a panel | `PanelKeyCatcher` |
| Text input, confirmation, dropdown | `TextField`, `ConfirmDialog`, `Dropdown` |
| Running a process | `Quickshell.Io.Process`, or `Util.execArgv` for a detached one |
| Authentication | `PamContext`, with the same services the lock screen uses |

`~/.local/share/omarchy/shell/plugins/README.md` documents the plugin contract,
and the first-party plugins beside it are worked examples — the clipboard picker
for an overlay, `panels/power` for a bar widget, `lock` for PAM.

Two habits follow from this. Read the first-party plugin that already solves
your problem before writing a line. And when something Omarchy provides does not
quite fit, say so in the commit — that is a much more interesting claim than it
looks, and usually wrong.

## Stay inside the plugin

**omaipsum never creates, edits or deletes a file outside its own directories.**

What is ours:

- the plugin directory, `~/.config/omarchy/plugins/cschaba.omaipsum`
- `~/.config/omaipsum/` — its config
- `~/.local/state/omaipsum/` — its log, backups and first-run marker
- the password store, and only through `pass`

Everything else belongs to the user, including `~/.config/hypr/bindings.lua` and
`~/.config/omarchy/shell.json`. Being careful about editing them — announcing
first, keeping a backup, touching only our own lines — is not the same as not
editing them, and a plugin that rewrites your compositor config is one you have
to trust twice.

Where something outside genuinely has to change, **detect it and print it**: the
exact line, or the exact command, and then stop. `install.sh` prints the
`o.bind` line for the keybinding and lets the user paste it.

Omarchy's own commands are the exception, because they are omarchy managing
omarchy's configuration and are what a user would type by hand:

```bash
omarchy plugin enable cschaba.omaipsum    # also places the bar widget
omarchy plugin disable cschaba.omaipsum
omarchy bar put cschaba.omaipsum
```

Prefer them over touching `shell.json`, which they own.

## Publishing

omaipsum is listed on the [Omarchy plugin marketplace][mp]. The listing points at
**the repository, not a release**, so a reviewer sees whatever is on `main` at
the moment they look. That is the sharper reason for the branch rule above:
`main` is the public face, not a workspace.

[mp]: https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/3086

### Promises already made

The submission form has a checklist, and it was ticked. Each item is a claim
about how omaipsum behaves, so a change that breaks one silently makes the
listing untrue:

- **"Does not overwrite user configuration without explicit consent."**
  omaipsum goes further than the checklist asks: it writes nothing outside its
  own directories at all. See *Stay inside the plugin* above. The easiest way to
  keep this claim true is to keep having nothing to declare.
- **"The repository is public and contains installation and removal
  instructions."** `uninstall.sh` has to keep working, and keep leaving the
  password store alone.
- **"Documented the licence and any external dependencies."** A new runtime
  dependency belongs in the README's Requirements table and in the startup
  requirements check, not only in the code that calls it.

### What the static scan reads

Every `.sh`, `.js`, `.mjs`, `.qml`, `.py`, `.rb`, `.pl`, `.lua`, `.yml`,
`.yaml`, `.toml`, `.desktop`, `.service`, `.sudoers`, `.bash`, `.fish`, `.zsh`
in the repository, plus extensionless files under `bin/` and `scripts/`, plus
the root README.

**Excluded:** anything under `tests/`, `docs/`, `.github/`, `spec/`, `specs/`,
`fixtures/`, `coverage/`, `node_modules/`.

So `bin/*`, `lib/config.sh`, `install.sh`, `uninstall.sh` and all the QML are
read; `tests/` and `docs/` are not. Worth knowing before adding anything that
shells out, invokes a package manager, or asks for `sudo`.

### Capabilities it will flag

These are detected and reported to the reviewer, and all of them are ours
already: `privilege` and `package-manager` (the guided setup offers to
`pacman -S` the dependencies), `installer` (the three scripts), and
`remote-build` (the `git clone` in the README). They are expected. A **new**
one appearing in a diff means the plugin started doing something categorically
different, and deserves a second look before it ships.
