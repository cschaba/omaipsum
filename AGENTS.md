# Working on omaipsum

Conventions for anyone — human or agent — making changes here, and the single
place that describes them: [CLAUDE.md](CLAUDE.md) is a pointer to this file,
nothing more. The reasoning behind the code is in
[DEVELOPMENT.md](DEVELOPMENT.md).

## Where things stand

omaipsum is an **Omarchy plugin** (Quickshell/QML, loaded by `omarchy-shell`)
— a bar widget that generates funny lorem-ipsum text. Three text variants, a
UI modelled on [Tiny Ipsum](https://macmenubar.com/tiny-ipsum/), and a count
selector over words, sentences and paragraphs.

**The plugin is written and runs.** `BarWidget.qml` is the bar icon and its
pulldown, `Ipsum.js` generates the text, `corpora/` holds the three variants as
data, `install.sh` and `uninstall.sh` register it with Omarchy through
Omarchy's own commands, `scripts/release.sh` cuts a release, `tests/` covers
both halves and `.github/workflows/ci.yml` runs the checks on every push.
[README.md](README.md) describes it for someone using it;
[DEVELOPMENT.md](DEVELOPMENT.md) describes the code.

The work began as thirteen issues across two milestones — `0.1.0 — generate and
copy` got a widget that produces text and copies it, `0.2.0 — shipping` added
install, tests, CI, a release script and a README worth reading — and has grown
since with the bugs and refinements that only running it turned up. Nothing has
been released yet: `manifest.json` still holds the `0.0.1` it was scaffolded
with, and everything since sits under `[Unreleased]` in the changelog.

A count of issues here would go stale the day after it was written, which is
its own small lesson: state what is durable, and let the tracker hold what is
not.

## Where it lives

**Everything lives on GitHub**: `origin`, `git@github.com:cschaba/omaipsum.git`,
public — code, issues, releases and CI. Gitea, at
`ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`, is a private **backup of
the code** and nothing more: pushed to, never worked in, never read from. If it
vanished tomorrow the only thing lost would be a spare copy.

The project started the other way round, and the reason for the swap is worth
keeping. The Gitea instance has no Actions runner, so a workflow committed
there could never run, and CI that cannot run is not CI. GitHub has runners; it
was already the address `manifest.json` gave as the homepage and the one the
README told people to clone, because a private instance is no use to somebody
installing a plugin; and a marketplace listing points at a repository rather
than a release. The code had to be where all three of those already pointed.

The issues followed the code (#20) rather than staying behind. Leaving them
would have left every `Fixes #N` in the history rendering as a dead link on the
public repository. GitHub had no issues and no pull requests yet, so numbering
started at 1 and the nineteen came across on their original numbers — which is
the only reason this was safe to do at all. Gitea keeps its copy; nothing
mirrors issues, so treat that copy as frozen history and file everything here.

## omapass is the reference

`cschaba/omapass` — checked out at `~/Projects/omapass`, symlinked into
`~/.config/omarchy/plugins/cschaba.omapass` — is the same author's finished
Omarchy plugin, and it is where this file and `DEVELOPMENT.md` started their
lives as copies. It is the worked example behind most of what is here:
`manifest.json`, `install.sh` and `uninstall.sh`, `scripts/release.sh`,
`tests/`, the CI jobs, and the bar-icon-with-a-pulldown shape in
`BarWidget.qml`. Its `DEVELOPMENT.md`
holds Quickshell traps that apply here unchanged; they are restated below.

Copying from it is the point. Copying from it *without reading* is how these
two files once came to describe a password manager: omaipsum handles no
secrets and needs no `pass`, GPG or PAM. When something read across from
omapass has no reason to exist on this side, take it out rather than leave it
somewhere it will be believed.

## An issue is scaffolding, the code is the building

**Before implementation an issue is the most valuable document there is** — it
states the goal, the constraints, and the decision to be made. Afterwards it
must not be the only place that knowledge lives.

Someone reading this repository in a year, with no network and no tracker and
no memory of the discussion, has to understand what the code does from the
code. So the code is verbose on purpose: comments explain the trap, the
constraint, the thing that would otherwise look arbitrary, and naming carries
intent. Nothing important is left implicit on the grounds that the issue
explains it.

**The one exception is the *why*.** Why a choice was made rather than the
obvious alternative is usually not derivable from the code at all — the code
shows the decision and never the options it beat or the reason they lost. That
reasoning does not stay in the tracker. It moves into the docs here, and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) is where the significant ones
live.

The test: **close the tracker, and nothing is lost but history.**

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
where that applies. Close issues with `Fixes #N` in the body — Gitea resolves
it against its own tracker when the mirror receives the push.

**Never write a closing keyword anywhere else in the message, not even to deny
it.** GitHub matches `close`/`fix`/`resolve` followed by `#N` wherever it
appears and does not read the sentence around it. A commit explaining that it
"does not close #29" closed #29. If a body needs to mention an issue it is not
finishing, write `Refs #N` and say the rest without the verb — "#29 stays open
because …".

Since #20 the tracker is on GitHub, so those references resolve where the code
is. They did not always: the issues came across from Gitea precisely so the
`Fixes #N` already written would keep pointing at the right thing. Say *why* the
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

```bash
./install.sh                                  # symlink the checkout in
omarchy restart shell                         # the only reliable QML reload
omarchy-shell cschaba.omaipsum.widget toggle  # open the bar pulldown
journalctl --user -f | grep omarchy-shell     # where QML errors land
tests/smoke.sh                                # manifest, QML, the scripts
tests/generator.sh                            # Ipsum.js, under node
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
- `~/.config/omaipsum/` and `~/.local/state/omaipsum/`, if a later version ever
  needs them. This one creates neither: the three settings live in `shell.json`
  where `omarchy bar set` keeps them, and nothing is logged or cached.
  `uninstall.sh --purge` removes both anyway, so a version that starts writing
  there does not also have to remember to teach the uninstaller.

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

**omaipsum is not on the [Omarchy plugin marketplace][mp], and has not been
submitted.** The public mirror was the prerequisite and it exists; the
submission itself is still to do. Nothing in this repository claims a listing,
and nothing should until one is made.

[mp]: https://github.com/HANCORE-linux/omarchy-plugin-marketplace

A listing points at **the repository, not a release**, so a reviewer sees
whatever is on `main` at the moment they look. That is the sharper reason for
the branch rule above: `main` is the public face, not a workspace.

### Promises a submission would make

The submission form is a checklist, and every item on it is a claim about how
the plugin behaves, made to people who cannot check it themselves. What
omaipsum could tick today, and what keeps each one true afterwards:

- **"Does not overwrite user configuration without explicit consent."**
  True, and worth stating precisely rather than grandly. omaipsum writes
  nothing outside its own directories *itself*. Installing it does change one
  file outside them — `~/.config/omarchy/shell.json` — because `install.sh`
  calls `omarchy plugin enable` and `omarchy bar put`, and Omarchy records the
  widget in its own config. That is the consent: running the installer is the
  request. See *Stay inside the plugin* above.

  The flat claim "writes nothing outside its own directories" was in the README
  and here, next to instructions that plainly registered a bar widget. A
  reviewer reading both would have caught the contradiction, and been right to
  wonder what else was overstated.
- **"The repository is public and contains installation and removal
  instructions."** True of the GitHub mirror, which is what a listing would
  point at; the README documents both directions. `uninstall.sh` has to keep
  working, and keep leaving `bindings.lua` alone.
- **"Documented the licence and any external dependencies."** MIT, and
  `wl-clipboard` is the only external dependency. A new one belongs in the
  README's Requirements table and in the startup probe beside `wl-copy`, not
  only in the code that calls it.

Whoever submits it is making these claims on the project's behalf, so check
them against the code on the day rather than against this list.

### What the static scan reads

Every `.sh`, `.js`, `.mjs`, `.qml`, `.py`, `.rb`, `.pl`, `.lua`, `.yml`,
`.yaml`, `.toml`, `.desktop`, `.service`, `.sudoers`, `.bash`, `.fish`, `.zsh`
in the repository, plus extensionless files under `bin/` and `scripts/`, plus
the root README.

**Excluded:** anything under `tests/`, `docs/`, `.github/`, `spec/`, `specs/`,
`fixtures/`, `coverage/`, `node_modules/`.

In this repository that means `install.sh`, `uninstall.sh`,
`scripts/release.sh`, `Ipsum.js`, `BarWidget.qml` and `README.md` are read;
`tests/` is not, `.github/` is not, and neither are the corpora, which are
`.json`. There is no `bin/` and no `lib/` here. Worth knowing before adding
anything that shells out, invokes a package manager, or asks for `sudo`.

The exclusion list names `.github/`, which is where the workflow now lives, so
the CI file is not read. It was in `.gitea/workflows` until #19 and was read
there — worth remembering if it ever moves back, because what a scanned CI file
does counts the same as what a shipped script does.

### Capabilities it will flag

These are detected and reported to the reviewer. Of omaipsum:

- `installer` — `install.sh`, `uninstall.sh` and `scripts/release.sh`.
- `remote-build` — the `git clone` and the `omarchy plugin add <url>` in the
  README.
- `privilege` and `package-manager` — **neither, now.** Nothing in the plugin
  runs `sudo` or a package manager: `install.sh` prints
  `omarchy pkg add wl-clipboard` when `wl-copy` is missing and installs
  nothing, and the widget execs exactly two binaries, `wl-copy` and
  `omarchy-notification-send`. The one file that does install packages is the
  CI workflow, with its `sudo apt-get install` — and moving it from
  `.gitea/workflows` to `.github/workflows` took it out of the scan, because
  the exclusion list names `.github/` and did not name `.gitea/`. That was a
  side effect of needing a runner rather than the reason for the move, but it
  is the honest current position: a scan of this repository should report
  neither capability.

A **new** capability appearing in a diff means the plugin started doing
something categorically different, and deserves a second look before it ships.
