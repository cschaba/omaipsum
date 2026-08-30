# Changing omaipsum

For someone editing the code: what is where, how to see an edit run, how to
test it, and the three ways a change looks broken when it is not.

[ARCHITECTURE.md](ARCHITECTURE.md) answers *why* the code is shaped like this
and is the place a decision's reasoning goes. [DEVOPS.md](DEVOPS.md) covers
the remotes, CI, releasing and what the install scripts do to a machine.
[../AGENTS.md](../AGENTS.md) has the conventions a change is expected to
follow — a branch per issue, a changelog entry as part of the fix, the Omarchy
API to reach for before writing anything.

## Layout

| Path | |
|------|--|
| `manifest.json` | the plugin manifest, and the only place the version lives |
| `BarWidget.qml` | the bar icon and everything in its pulldown |
| `Ipsum.js` | the generator: pure functions, no QML types, no I/O |
| `corpora/` | one JSON file per text variant; the widget reads the directory |
| `corpora/README.md` | the corpus schema, and where words may come from |
| `install.sh` | symlinks the checkout in and registers it through omarchy |
| `uninstall.sh` | unregisters, removes the link, `--purge` for state |
| `scripts/release.sh` | cuts a release, or refuses before writing anything |
| `tests/smoke.sh` | everything that is not the generator |
| `tests/generator.sh` | `Ipsum.js`, exercised under node |
| `.github/workflows/ci.yml` | the four CI jobs |
| `README.md` | for people using omaipsum rather than working on it |
| `DEVELOPMENT.md` | a pointer at the three documents in `docs/` |
| `docs/DEVELOPER.md` | this file |
| `docs/DEVOPS.md` | remotes, CI, releasing, install mechanics |
| `docs/ARCHITECTURE.md` | why the code is shaped the way it is |
| `AGENTS.md` | the conventions, the Omarchy API table, the process rules |
| `CLAUDE.md` | a pointer at `AGENTS.md`, and nothing else |
| `CHANGELOG.md` | what changed when |
| `LICENSE` | MIT |

## What to change where

| To change | Edit |
|---|---|
| the words a variant draws from | one file in `corpora/`, and nothing else |
| how sentences and paragraphs are built | `Ipsum.js` |
| the panel, the keys, the bar icon, the clipboard | `BarWidget.qml` |
| the settings the bar UI offers | `manifest.json` and its twin in the QML |

The last row is a trap and [ARCHITECTURE.md](ARCHITECTURE.md) explains it:
`barWidget.defaults` never reaches the widget, so the QML fallbacks are the
real defaults and nothing checks that the two agree.

A new variant is one new file. The widget scans `corpora/` at startup rather
than importing a list, so a fourth file is a fourth entry in the picker after
a shell restart — see [../corpora/README.md](../corpora/README.md) for the
schema every file has to satisfy.

## The local loop

`install.sh` symlinks your checkout into
`~/.config/omarchy/plugins/cschaba.omaipsum`, so an edit is live without
reinstalling — but you have to ask for the reload:

```bash
./install.sh                                  # once
omarchy restart shell                         # after every QML or JS edit
omarchy-shell cschaba.omaipsum.widget toggle  # open the pulldown
journalctl --user -f | grep omarchy-shell     # where QML errors land
qmllint -I /usr/share/omarchy/shell *.qml     # type checking, locally
```

The toggle target is the widget's own `ipcTarget` in `BarWidget.qml`, which
`Ui/Panel.qml` gives open, close and toggle. It is the same command
`install.sh` prints for the optional keybinding, and the same one
`uninstall.sh` greps `bindings.lua` for on the way out.

## Three ways a change looks broken when it is not

These are the ones that cost an afternoon. [../AGENTS.md](../AGENTS.md)
states them as a rule for anyone making a change; here is what to do about
each.

**QML is cached for the life of the shell process.** `omarchy-shell` loads a
plugin's QML once at startup and keeps it, so nothing you edit takes effect
until `omarchy restart shell`. `rescanPlugins` is not a substitute: the shell
watches `~/.config/omarchy/plugins` with `inotifywait -r`, which does not
follow symlinked directories, so a linked checkout never fires it.

**A bar widget root must publish its own implicit size.** The bar sizes each
slot from the active item's `implicitWidth`/`implicitHeight`, so a root that
does not set them gets a 0×0 slot and renders nothing — no icon, no gap, no
error, no log line. The two lines that do it in `BarWidget.qml` are commented
in place, because the failure gives you no other clue. Omarchy's own
`plugins/panels/power/Panel.qml` does the same thing explicitly.

**Omarchy's Loader swallows plugin load errors.** Its panel Loader error path
calls `errorString()` as a function, which throws, so the real message is
lost. To find out what a file actually says, load it in a throwaway Quickshell
config *outside* the shell's config root — inside it, Quickshell treats the
directory as a module and sibling types stop resolving, which produces
misleading `X is not a type` errors instead of the one you are hunting.

Two smaller ones live in the code, commented where they bite. `qs.Commons` and
`qs.Ui` resolve only inside the running shell, so `qmllint` outside it rejects
every file over an unresolved import regardless of syntax — hence the `-I`
flag above, and hence CI parsing with `qmlformat` instead. And
`QtQuick.Controls` exports its own `Button` and `ButtonGroup`: an unaligned
import puts two different types behind those names, and picking up Controls'
non-visual `ButtonGroup` loses the unit row entirely with nothing in the log.

## Testing

```bash
tests/smoke.sh       # 47 checks: the manifest, the schema, the QML, the scripts
tests/generator.sh   # 103 checks: counts, shape, determinism, the corpora
```

`smoke.sh` covers everything that is not the generator. It mirrors what
`PluginRegistry.validateManifest` enforces in the running shell, because a
manifest the shell rejects produces no error a user ever sees — the plugin
simply is not there. It also checks that the settings schema and the defaults
beside it agree, that the unit enum is exactly `Ipsum.js`'s `UNITS`, and that
the default variant names a corpus that exists; parses every QML file with
`qmlformat`; and confirms every shell script parses and is executable.

`generator.sh` strips the `.pragma library` line off `Ipsum.js`, evaluates the
rest in node, and asks the three questions worth asking of a generator: that
the counts are exact, that sentence and paragraph lengths stay inside the
bounds the file declares, and that the same seed gives the same text — the
preview and the string that reaches the clipboard are two separate calls and
have to agree. Its regression anchors run against a fixture corpus defined in
the test rather than a shipped one, so editing a word list — which the README
invites — cannot fail a test that is not about it.

Both redirect `HOME` and the `XDG_*` variables into a throwaway directory and
clean up after themselves. Both *skip* rather than fail when `node` or
`qmlformat` is missing, which is right on a developer's machine and wrong on a
runner — [DEVOPS.md](DEVOPS.md) has what CI does about that.

Two findings from writing the suite are worth keeping.

**The dispatcher check earns its keep.** It walks every `case` branch in every
shell script and confirms the name the branch calls resolves to something: a
function defined in the same file, a shell builtin or keyword, or a known
external. bash only complains when a branch is actually taken, so a subcommand
dispatched to a function that has been deleted parses cleanly, passes `bash
-n`, passes every other check here, and dies the first time a user picks it.
omapass shipped exactly that twice.

**Resolving those names through `PATH` was itself a bug.** Looking externals up
with `command -v` makes the answer depend on the machine, in both directions:
a tool missing from CI fails a branch that is fine, and — the reason the
allowlist exists — this development box has a real `/usr/bin/usage`, which
quietly resolved a `release.sh` branch calling a `usage` function that had been
deleted. The check was hiding the precise failure it was written to catch.
Externals are an explicit set in `tests/smoke.sh` now, and a new one in a case
branch is a one-line addition to it.

## Issues and pull requests from the terminal

The tracker is on GitHub, so `gh` is the tool: `gh issue list`,
`gh issue view N`, `gh issue close N`, `gh pr create`. Commits close their
issue with `Fixes #N`, which resolves there — see
[../AGENTS.md](../AGENTS.md) for the commit conventions and
[ARCHITECTURE.md](ARCHITECTURE.md) for why the tracker moved.

The `tea` CLI drives Gitea the same way — `tea issues`, `tea issue close`,
`tea pr create` — but Gitea holds only a backup of the code and a frozen copy
of the issues as they stood at the move. File nothing there. If you do reach
for it: on the development machine `tea` authenticates as `omarchy-ai`, which
needs access to `carsten/omaipsum`, and without it every command answers `not
found` — which reads like a mistyped repository name and is not. It is Gitea
declining to admit the repository exists. Check the access before debugging
the command.
