# Working on OmaIpsum

Conventions for anyone — human or agent — making changes here, and the single
place that describes them: [CLAUDE.md](CLAUDE.md) is a pointer to this file,
nothing more. The reasoning behind the code is in
[DEVELOPMENT.md](DEVELOPMENT.md).

## Shared memory

General lessons that apply across the maintainer's projects — verification
habits, git and release conventions, shell scripting traps, Omarchy plugin
pitfalls, publishing and security — live outside this repository in
`~/AI-Memory/`. If that directory exists on your machine, read
`~/AI-Memory/README.md` and the topic relevant to the task before starting.

Project-specific rules belong in this file. When a decision made here is
general — it would hold for other projects too — add it to `~/AI-Memory` as
well, or correct it there if it has changed or proved wrong. Review that memory
from time to time rather than letting it go stale.

## Where things stand

OmaIpsum is an **Omarchy plugin** (Quickshell/QML, loaded by `omarchy-shell`)
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
two files once came to describe a password manager: OmaIpsum handles no
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

**OmaIpsum never creates, edits or deletes a file outside its own directories.**

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

**OmaIpsum is listed on the [Omarchy plugin marketplace][mp]**, published and
verified on 2026-08-31 by `maintainer-reviewed`:
https://plugins.omarchy.org/plugin.html?id=cschaba.omaipsum

[mp]: https://github.com/omacom/omarchy-plugin-marketplace

Verification covers the exact snapshot that was reviewed, and is explicitly not
a security audit. Plugins run unsandboxed, so what makes this one safe to
install is a property of the repository rather than of anyone's approval.

A listing points at **the repository, not a release**, so a reviewer sees
whatever is on `main` at the moment they look. That is the sharper reason for
the branch rule above: `main` is the public face, not a workspace.

### Promises a submission would make

The submission form is a checklist of **five** items, every one of them
`required: true` and every one a claim about how the plugin behaves, made to
people who cannot check it themselves. Verbatim from the marketplace's
`.github/ISSUE_TEMPLATE/submit-plugin.yml`, with what makes each true here and
what keeps it true afterwards:

1. **"The repository is public and contains installation and removal
   instructions."** True: public, and the README documents both directions.
   `uninstall.sh` has to keep working, and keep leaving `bindings.lua` alone.
2. **"I have documented the plugin license and any external dependencies."**
   MIT, in `LICENSE` and in the manifest; `wl-clipboard` is the only external
   dependency. A new one belongs in the README's Requirements table and in the
   startup probe beside `wl-copy`, not only in the code that calls it.
3. **"I confirm that I own or have permission to submit this plugin and its
   preview assets."** The corpora carry per-file `attribution` and `source`,
   `corpora/README.md` sets a conservative rule, and the screenshots and the
   screencast are the maintainer's own. This is the one item no review of the
   code can settle for you — it is a provenance claim, and it is yours.
4. **"The plugin does not overwrite user configuration without explicit
   consent."** True, and worth stating precisely rather than grandly. OmaIpsum
   writes nothing outside its own directories *itself*. Installing it does
   change one file outside them — `~/.config/omarchy/shell.json` — because
   `install.sh` calls `omarchy plugin enable` and `omarchy bar put`, and
   Omarchy records the widget in its own config. That is the consent: running
   the installer is the request. See *Stay inside the plugin* above.

   The flat claim "writes nothing outside its own directories" was in the
   README and here, next to instructions that plainly registered a bar widget.
   A reviewer reading both would have caught the contradiction, and been right
   to wonder what else was overstated.
5. **"I understand that approval is for listing and is not a security
   review."** Accepted by submitting, and worth internalising rather than
   ticking: see *What a listing is not* below.

Whoever submits it is making these claims on the project's behalf, so check
them against the code on the day rather than against this list.

### What the static scan reads

Read out of the marketplace's own `scripts/security-baseline-scope.mjs` and
confirmed by running it — the file list below is what its
`resolveSecuritySnapshot()` returned for this repository at `dfc986b` on
2026-09-15, not a guess from the prose.

**Directory exclusions are applied first**, and they beat every rule below
except a manifest entry point: any path with `.github`, `coverage`, `docs`,
`fixtures`, `node_modules`, `spec`, `specs`, `test` or `tests` as a *directory*
component is out.

What is left is read if it matches **any** of:

- one of these extensions — `.bash` `.cjs` `.desktop` `.fish` `.js` `.lua`
  `.mjs` `.pl` `.py` `.qml` `.rb` `.service` `.sh` `.sudoers` `.toml` `.yaml`
  `.yml` `.zsh`;
- it is the **root README**, under any extension;
- it is committed **executable** (mode `100755`), wherever it lives;
- it has **no extension at all**, wherever it lives — not only under `bin/` and
  `scripts/`;
- its basename contains `install`, `installer`, `setup` or `uninstall`;
- it is an **`entryPoints` path** from the validated manifest, which is forced
  in *even from an excluded directory*.

In this repository that is exactly seven files:

```
BarWidget.qml  Ipsum.js  LICENSE  README.md
install.sh  scripts/release.sh  uninstall.sh
```

`LICENSE` is in the list because it has no extension, which is worth knowing
before putting anything else at the root without one. `tests/smoke.sh` and
`tests/generator.sh` are committed executable and would qualify twice over, but
the directory exclusion is applied first and takes them out. The corpora are
`.json` and are read by nothing. `manifest.json` is read as the manifest, not
as scanned source.

The exclusion list names `.github/`, which is where the workflows live, so
`ci.yml` and `release.yml` are not read. They were in `.gitea/workflows` until
#19 and were read there — worth remembering if they ever move back, because
what a scanned CI file does counts the same as what a shipped script does.

### What the scan reports today

Run against `dfc986b` on 2026-09-15 with the marketplace's own scanner. The
verdict is `outcome: needs-fixes`, `disposition: review-required`,
`enforcementMode: selective`, **`blocksApproval: false`** — a listing is not
refused over any of it.

**Three capabilities**, all correct and none of them a defect:

- `installer` — `install.sh:1` and `uninstall.sh:1`, matched on the filename.
- `remote-build` — the `git clone` in the README and `git fetch` in
  `scripts/release.sh:185`.
- `package-manager` — `README.md:55` and `install.sh:163`, both of which *tell
  the user* to run `omarchy pkg add wl-clipboard` and neither of which runs
  anything. The rule is a literal regex, and for the root README every line is
  treated as a command, so it cannot tell advice from execution.

  **This is accepted rather than worked around.** Rewording two lines so the
  string does not appear would trade good documentation for a tidier report,
  and the report is not a failure. `docs/DEVOPS.md` carries the note to paste
  into the submission form's *Maintainer notes* saying so. An earlier version
  of this file predicted the capability would not be reported; it is.
- `privilege` — **not** reported, and that is a property worth keeping. Nothing
  in the plugin runs `sudo` or a package manager: `install.sh` prints the
  `omarchy pkg add` line and installs nothing, and the widget starts three
  binaries and no shell — `wl-copy` and `omarchy-notification-send` through a
  `Process`, `omarchy-launch-browser` through `execDetached`, each with a
  constant argv array. The one file that really does install packages is the CI
  workflow, and `.github/` is outside the scan.

**One finding**, `remote-git-execution-unpinned`, on `scripts/release.sh:185`
and `:254`. It is a false positive: the scanner pairs a `git fetch` with a
later "execution sink" in the same file, the fetch targets `$REMOTE` rather
than a submission repository, and the sink is `bash -n`, which parses a local
file and executes nothing. `scripts/release.sh` is a maintainer tool that no
user runs and that the release tarball excludes.

A **new** capability or finding appearing in a diff means the plugin started
doing something categorically different, and deserves a second look before it
ships.

### What a listing is not

The publish page says it plainly: **the marketplace validates listings, not
plugin security**, and **plugins run unsandboxed**. A listed plugin has had its
manifest validated, its repository confirmed public, its author's checkboxes
recorded, and a regex scan run over seven files. Once installed, its QML runs
inside `omarchy-shell` with the user's full privileges — same filesystem, same
D-Bus session, same ability to exec anything on `PATH`.

What makes this one safe to install is therefore a property of the repository
and not of anyone's approval: a small surface, three binaries with constant
argv, no network, no writes, no privilege. The thing a user is really trusting
is that it stays that way — which is what `remote-build` is quietly about,
because a listing points at a repository and what installs is whatever is on
`main` at that moment, not the commit anyone reviewed.
